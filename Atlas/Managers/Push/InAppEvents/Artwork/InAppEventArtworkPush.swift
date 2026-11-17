//
//  InAppEventArtworkPush.swift
//  Atlas
//

import Foundation

/// One event card or details page the push uploads into one language of
/// an event. Its request is the reservation itself with the file on this
/// Mac under `atlas.file`, so the queue shows what goes out. The
/// push reads the file, reserves it, uploads its parts, commits it, waits
/// for Apple to process it, then deletes what that asset type had (images
/// and videos alike), so the new art replaces it. When Apple refuses a
/// second one of the type, the old one is deleted first.
struct InAppEventArtworkPush: Hashable, Sendable {
    var localizationID: String
    var kind: InAppEventMedia.Kind
    var isVideo: Bool
    var fileName: String
    var fileSize: Int
    /// The file in Atlas's own folder.
    var path: String
    /// "00:00:02:00": a video's poster frame, as HH:MM:SS:FF.
    var previewFrameTimeCode: String?

    static let fileKey = "atlas"
    static let pollInterval: Duration = .seconds(2)
    static let imageTimeout: Duration = .seconds(180)
    static let videoTimeout: Duration = .seconds(900)

    init(
        localizationID: String, kind: InAppEventMedia.Kind, isVideo: Bool, fileName: String, fileSize: Int, path: String,
        previewFrameTimeCode: String? = nil
    ) {
        self.localizationID = localizationID
        self.kind = kind
        self.isVideo = isVideo
        self.fileName = fileName
        self.fileSize = fileSize
        self.path = path
        self.previewFrameTimeCode = isVideo ? previewFrameTimeCode : nil
    }

    /// The step a queued change carries; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post,
              let isVideo = [false, true].first(where: { InAppEventArtworkRequests.collectionPath(isVideo: $0) == request.path }),
              let body = request.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let meta = body[Self.fileKey] as? [String: Any], let path = meta["file"] as? String,
              let data = body["data"] as? [String: Any], let attributes = data["attributes"] as? [String: Any],
              let fileName = attributes["fileName"] as? String, let fileSize = attributes["fileSize"] as? Int,
              let kind = (attributes["appEventAssetType"] as? String).flatMap(InAppEventMedia.Kind.init(rawValue:)),
              let relationships = data["relationships"] as? [String: Any],
              let localization = (relationships["appEventLocalization"] as? [String: Any])?["data"] as? [String: Any],
              let localizationID = localization["id"] as? String
        else { return nil }
        self.init(
            localizationID: localizationID, kind: kind, isVideo: isVideo, fileName: fileName, fileSize: fileSize, path: path,
            previewFrameTimeCode: attributes["previewFrameTimeCode"] as? String
        )
    }

    /// The reservation with the file added, for the queue.
    var request: PushRequest {
        var reserve = InAppEventArtworkRequests.reserve(
            fileName: fileName, fileSize: fileSize, kind: kind, isVideo: isVideo, localizationID: localizationID,
            previewFrameTimeCode: previewFrameTimeCode
        )
        guard var body = reserve.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else { return reserve }
        body[Self.fileKey] = ["file": path]
        reserve.body = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return reserve
    }

    /// Uploads the file and replaces what the asset type had. Returns the
    /// new image's or video's ID.
    @MainActor
    @discardableResult
    func send(
        via transport: any PushTransport,
        readFile: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) },
        sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        note: (AppStoreConnectRateLimit?) -> Void = { _ in },
        progress: (String) -> Void = { _ in }
    ) async throws -> String {
        guard let uploads = transport as? any ScreenshotUploadTransport else { throw InAppEventArtworkPushError.cannotUpload }
        let data: Data
        do {
            data = try readFile(path)
        } catch {
            throw InAppEventArtworkPushError.fileMissing(fileName: fileName)
        }
        var old = try await existing(via: transport, note: note)
        let reserve = InAppEventArtworkRequests.reserve(
            fileName: fileName, fileSize: data.count, kind: kind, isVideo: isVideo, localizationID: localizationID,
            previewFrameTimeCode: previewFrameTimeCode
        )
        let response: AppStoreConnectResponse
        do {
            response = try await transport.send(reserve)
        } catch let AppStoreConnectError.rejected(statusCode, _, _) where statusCode == 409 && !old.isEmpty {
            // One of the type already: make room, then reserve again.
            try await delete(old, via: transport, note: note)
            old = []
            response = try await transport.send(reserve)
        }
        note(response.rateLimit)
        let reservation = try InAppEventArtworkRequests.reservation(in: response.data)
        for (index, operation) in reservation.operations.enumerated() {
            progress(String(localized: "Uploading \(kind.name) · part \(index + 1) of \(reservation.operations.count)"))
            try await uploads.upload(operation, data: data) { _ in }
        }
        let commitRequest = InAppEventArtworkRequests.commit(id: reservation.id, isVideo: isVideo, previewFrameTimeCode: previewFrameTimeCode)
        let commit = try await transport.send(commitRequest)
        note(commit.rateLimit)
        progress(String(localized: "Apple is processing the \(kind.name)"))
        try await waitUntilProcessed(reservation.id, via: transport, sleep: sleep, note: note)
        try await delete(old, via: transport, note: note)
        return reservation.id
    }

    /// The images and videos of this asset type the localization has now.
    @MainActor
    private func existing(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [(id: String, isVideo: Bool)] {
        var found: [(id: String, isVideo: Bool)] = []
        for video in [false, true] {
            let response = try await transport.fetch(InAppEventArtworkRequests.existingPath(localizationID: localizationID, isVideo: video))
            note(response.rateLimit)
            found += try InAppEventArtworkRequests.existingIDs(in: response.data, kind: kind).map { ($0, video) }
        }
        return found
    }

    @MainActor
    private func delete(_ media: [(id: String, isVideo: Bool)], via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws {
        for item in media {
            do {
                try await note(transport.send(InAppEventArtworkRequests.delete(id: item.id, isVideo: item.isVideo)).rateLimit)
            } catch AppStoreConnectError.notFound {
                // Already gone.
            }
        }
    }

    @MainActor
    private func waitUntilProcessed(
        _ id: String, via transport: any PushTransport, sleep: (Duration) async throws -> Void, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        let timeout = isVideo ? Self.videoTimeout : Self.imageTimeout
        var waited: Duration = .zero
        while true {
            let response = try await transport.fetch(InAppEventArtworkRequests.statusPath(id: id, isVideo: isVideo))
            note(response.rateLimit)
            let state = InAppEventArtworkRequests.deliveryState(in: response.data, isVideo: isVideo)
            if state?.isComplete == true { return }
            if state?.isFailed == true {
                let details = state?.errors?.compactMap { $0.description ?? $0.code }.joined(separator: " ")
                throw InAppEventArtworkPushError.refused(fileName: fileName, details: details?.isEmpty == false ? details : nil)
            }
            guard waited < timeout else { throw InAppEventArtworkPushError.timedOut(fileName: fileName) }
            try await sleep(Self.pollInterval)
            waited += Self.pollInterval
        }
    }
}
