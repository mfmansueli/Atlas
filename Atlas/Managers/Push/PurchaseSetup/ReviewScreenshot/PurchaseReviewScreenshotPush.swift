//
//  PurchaseReviewScreenshotPush.swift
//  Atlas
//

import Foundation

/// A subscription's or in-app purchase's App Review screenshot upload. Its
/// queued request is the reservation itself (`POST
/// /v1/subscriptionAppStoreReviewScreenshots` or
/// `/v1/inAppPurchaseAppStoreReviewScreenshots`) with the file on this Mac
/// and its MD5 under `atlas`, so the queue shows what goes out; the owner
/// may be `{createdID:<type>}` when the change creates it.
///
/// The push reads what the product has: the same file already processed
/// counts as done (a push that stopped after it); another one is deleted
/// first, since a product has only one. Then it reserves the file, uploads
/// its parts, commits it with its checksum and waits for Apple's
/// processing.
struct PurchaseReviewScreenshotPush: Hashable, Sendable {
    var owner: PurchaseReviewScreenshotOwner
    var ownerID: String
    var fileName: String
    var fileSize: Int
    /// The file in Atlas's own folder.
    var path: String
    /// MD5, lowercase hex.
    var checksum: String

    static let fileKey = "atlas"
    static let pollInterval: Duration = .seconds(2)
    static let timeout: Duration = .seconds(180)

    init(owner: PurchaseReviewScreenshotOwner, ownerID: String, fileName: String, fileSize: Int, path: String, checksum: String) {
        self.owner = owner
        self.ownerID = ownerID
        self.fileName = fileName
        self.fileSize = fileSize
        self.path = path
        self.checksum = checksum
    }

    /// The step a queued change carries; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post,
              let owner = [PurchaseReviewScreenshotOwner.subscription, .inAppPurchase].first(where: { $0.collectionPath == request.path }),
              let body = request.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let meta = body[Self.fileKey] as? [String: Any], let path = meta["file"] as? String,
              let data = body["data"] as? [String: Any], let attributes = data["attributes"] as? [String: Any],
              let fileName = attributes["fileName"] as? String, let fileSize = attributes["fileSize"] as? Int,
              let relationship = ((data["relationships"] as? [String: Any])?[owner.relationship] as? [String: Any])?["data"] as? [String: Any],
              let ownerID = relationship["id"] as? String
        else { return nil }
        self.init(owner: owner, ownerID: ownerID, fileName: fileName, fileSize: fileSize, path: path, checksum: meta["checksum"] as? String ?? "")
    }

    /// The reservation with the file added, for the queue.
    var request: PushRequest {
        var body = Self.reservationBody(owner: owner, ownerID: ownerID, fileName: fileName, fileSize: fileSize)
        body[Self.fileKey] = ["file": path, "checksum": checksum]
        return Self.request(.post, owner.collectionPath, body)
    }

    /// The `POST` Apple gets, without Atlas's own key.
    var reservation: PushRequest {
        Self.request(.post, owner.collectionPath, Self.reservationBody(owner: owner, ownerID: ownerID, fileName: fileName, fileSize: fileSize))
    }

    /// `PATCH …/{id}`: every part is up; here's its MD5.
    func commit(id: String) -> PushRequest {
        Self.request(.patch, "\(owner.collectionPath)/\(id)", [
            "data": ["type": owner.screenshotType, "id": id, "attributes": ["uploaded": true, "sourceFileChecksum": checksum]],
        ])
    }

    func delete(id: String) -> PushRequest {
        PushRequest(method: .delete, path: "\(owner.collectionPath)/\(id)", body: nil)
    }

    // MARK: - Sending

    /// Uploads the file, replacing the screenshot the product had. Returns
    /// the screenshot's ID once Apple has processed it.
    @MainActor
    @discardableResult
    func send(
        via transport: any PushTransport,
        readFile: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) },
        sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        note: (AppStoreConnectRateLimit?) -> Void = { _ in },
        progress: (String) -> Void = { _ in }
    ) async throws -> String {
        guard let uploads = transport as? any ScreenshotUploadTransport else { throw PurchaseReviewScreenshotPushError.cannotUpload }
        let data: Data
        do {
            data = try readFile(path)
        } catch {
            throw PurchaseReviewScreenshotPushError.fileMissing(fileName: fileName)
        }
        let checksum = checksum.isEmpty ? ScreenshotPNG.checksum(data) : checksum
        if let current = try await current(via: transport, note: note) {
            if case let .uploaded(_, sum) = current.state, sum == checksum { return current.id }
            do {
                try await note(transport.send(delete(id: current.id)).rateLimit)
            } catch AppStoreConnectError.notFound {
                // Already gone.
            }
        }
        var step = self
        step.fileSize = data.count
        step.checksum = checksum
        let reserved = try await transport.send(step.reservation)
        note(reserved.rateLimit)
        let (id, operations) = try Self.reservation(in: reserved.data)
        for (index, operation) in operations.enumerated() {
            progress(String(localized: "Pushing the review screenshot · part \(index + 1) of \(operations.count)"))
            try await uploads.upload(operation, data: data) { _ in }
        }
        try await note(transport.send(step.commit(id: id)).rateLimit)
        progress(String(localized: "Apple is processing the review screenshot"))
        try await waitUntilProcessed(id, via: transport, sleep: sleep, note: note)
        return id
    }

    /// The product's screenshot now, if it has one.
    @MainActor
    private func current(
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> (id: String, state: PurchaseReviewScreenshotState)? {
        let response: AppStoreConnectResponse
        do {
            response = try await transport.fetch(owner.currentPath(ownerID: ownerID))
        } catch AppStoreConnectError.notFound {
            return nil
        }
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        guard let resource = object?["data"] as? [String: Any], let id = resource["id"] as? String else { return nil }
        return (id, PurchaseReviewScreenshotState(resource: resource))
    }

    @MainActor
    private func waitUntilProcessed(
        _ id: String,
        via transport: any PushTransport,
        sleep: (Duration) async throws -> Void,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        var waited: Duration = .zero
        while true {
            let response = try await transport.fetch(owner.statusPath(id: id))
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            let attributes = (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
            let delivery = attributes?["assetDeliveryState"] as? [String: Any]
            switch delivery?["state"] as? String {
            case "COMPLETE":
                return
            case "FAILED":
                let errors = delivery?["errors"] as? [[String: Any]] ?? []
                let details = errors.compactMap { ($0["description"] ?? $0["code"]) as? String }.joined(separator: " ")
                throw PurchaseReviewScreenshotPushError.refused(fileName: fileName, details: details.isEmpty ? nil : details)
            default:
                guard waited < Self.timeout else { throw PurchaseReviewScreenshotPushError.timedOut(fileName: fileName) }
                try await sleep(Self.pollInterval)
                waited += Self.pollInterval
            }
        }
    }

    // MARK: - Documents

    /// A reservation's ID and upload operations, in file order.
    static func reservation(in data: Data) throws -> (id: String, operations: [ScreenshotUploadOperation]) {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let resource = object?["data"] as? [String: Any]
        let raw = (resource?["attributes"] as? [String: Any])?["uploadOperations"] as? [[String: Any]] ?? []
        guard let id = resource?["id"] as? String, !raw.isEmpty,
              let encoded = try? JSONSerialization.data(withJSONObject: raw),
              let operations = try? JSONDecoder().decode([ScreenshotUploadOperation].self, from: encoded)
        else { throw AppStoreConnectError.unexpectedPayload }
        return (id, operations.sorted { $0.offset < $1.offset })
    }

    private static func reservationBody(owner: PurchaseReviewScreenshotOwner, ownerID: String, fileName: String, fileSize: Int) -> [String: Any] {
        [
            "data": [
                "type": owner.screenshotType,
                "attributes": ["fileName": fileName, "fileSize": fileSize],
                "relationships": [owner.relationship: ["data": ["type": owner.ownerType, "id": ownerID]]],
            ],
        ]
    }

    private static func request(_ method: PushRequest.Method, _ path: String, _ body: [String: Any]) -> PushRequest {
        let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return PushRequest(method: method, path: path, body: data)
    }
}
