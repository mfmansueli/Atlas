//
//  ProductPageScreenshotsPush.swift
//  Atlas
//

import Foundation

/// One language's screenshots (or App Previews) on one device for a custom
/// product page (board 52), made by Make Screenshots for This Page or
/// chosen with Choose Files…. The push finds the
/// page's version that takes edits (or makes one, once per page in a
/// push), the language (made when the version hasn't it) and its set of
/// that device (made when it has none), uploads each screenshot, waits for
/// Apple to process them, deletes the ones the set had and puts the new
/// ones in order. The default page's screenshots don't change.
///
/// It travels in Review & Push as a `POST /v1/appScreenshotSets` whose body
/// is this push (`ProductPageScreenshotsPush.Body`), never sent as is.
struct ProductPageScreenshotsPush: Hashable, Sendable {
    struct Body: Codable, Hashable, Sendable {
        var productPageScreenshots: Content
    }

    struct File: Codable, Hashable, Sendable {
        /// On this Mac, in `PageShotsStudio`'s folder.
        var path: String
        var fileName: String
        var fileSize: Int
        /// MD5.
        var checksum: String
        /// An App Preview's type, e.g. "video/quicktime"; nil for a
        /// screenshot.
        var mimeType: String?
    }

    struct Content: Codable, Hashable, Sendable {
        var appID: String
        /// A draft's ID until it's pushed: the push finds the page by name.
        var pageID: String
        var pageName: String
        /// The deep link a version this push makes keeps.
        var currentDeepLink: String?
        var locale: String
        var displayType: ScreenshotDisplayType
        var files: [File]
        /// Nil (from before App Previews) is screenshots.
        var media: ProductPageMedia?
    }

    static let path = "/v1/appScreenshotSets"
    static let maxScreenshots = 10
    static let pollInterval: Duration = .seconds(2)
    static let timeout: Duration = .seconds(180)

    var content: Content

    var media: ProductPageMedia { content.media ?? .screenshots }

    init(_ content: Content) {
        self.content = content
    }

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let body = request.body,
              let decoded = try? JSONDecoder().decode(Body.self, from: body)
        else { return nil }
        content = decoded.productPageScreenshots
    }

    var request: PushRequest {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = (try? encoder.encode(Body(productPageScreenshots: content))) ?? Data()
        return PushRequest(method: .post, path: Self.path, body: body)
    }

    /// The page is a draft made in Atlas: its ID is found by name.
    var needsPageID: Bool { ProductPageDraft.isDraftID(content.pageID) }

    /// Changes of one page's language wait for each other: they share its
    /// localization.
    var resourceKey: String { "pageScreenshots:\(content.appID):\(ProductPageBrief.key(content.pageName)):\(content.locale)" }

    // MARK: - Requests

    static func pagesPath(appID: String) -> String {
        "/v1/apps/\(appID)/appCustomProductPages?fields%5BappCustomProductPages%5D=name&limit=200"
    }

    /// The page named `name` in a pages response, case and spaces at the
    /// ends ignored.
    static func pageID(named name: String, in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let pages = object?["data"] as? [[String: Any]] ?? []
        return pages.first { page in
            let attributes = page["attributes"] as? [String: Any]
            return (attributes?["name"] as? String).map(ProductPageBrief.key) == ProductPageBrief.key(name)
        }?["id"] as? String
    }

    func setsPath(localizationID: String) -> String {
        media.setsPath(localizationID: localizationID, displayType: content.displayType)
    }

    func createSet(localizationID: String) -> PushRequest {
        media.createSet(localizationID: localizationID, displayType: content.displayType)
    }

    /// The set of this device in a sets response, and what it holds.
    func existingSet(in data: Data) throws -> (id: String, screenshotIDs: [String])? {
        try media.existingSet(in: data, displayType: content.displayType).map { ($0.id, $0.itemIDs) }
    }

    // MARK: - Sending

    /// Uploads the screenshots into `localizationID` and replaces what its
    /// set of this device had. Returns the set's ID.
    @MainActor
    @discardableResult
    func send(
        into localizationID: String,
        via transport: any PushTransport,
        readFile: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) },
        sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        note: (AppStoreConnectRateLimit?) -> Void = { _ in },
        progress: (String) -> Void = { _ in },
        processing: () -> Void = {},
        pollInterval: () -> Duration = { Self.pollInterval }
    ) async throws -> String {
        guard let uploads = transport as? any ScreenshotUploadTransport else { throw ProductPageScreenshotsPushError.cannotUpload }
        var files: [(file: File, data: Data)] = []
        for file in content.files {
            do {
                try files.append((file, readFile(file.path)))
            } catch {
                throw ProductPageScreenshotsPushError.fileMissing(fileName: file.fileName)
            }
        }
        let sets = try await transport.fetch(setsPath(localizationID: localizationID))
        note(sets.rateLimit)
        let setID: String
        var old: [String] = []
        if let existing = try existingSet(in: sets.data) {
            setID = existing.id
            old = existing.screenshotIDs
        } else {
            let created = try await transport.send(createSet(localizationID: localizationID))
            note(created.rateLimit)
            setID = try ScreenshotUploadRequests.createdID(in: created.data)
        }
        // A set takes 10: make room first when the new ones wouldn't fit.
        if old.count + files.count > media.limit {
            try await delete(old, via: transport, note: note)
            old = []
        }
        var uploaded: [String] = []
        for (index, item) in files.enumerated() {
            progress(media == .appPreviews
                ? String(localized: "Uploading App Preview \(index + 1) of \(files.count)")
                : String(localized: "Uploading screenshot \(index + 1) of \(files.count)"))
            let reserve = try await transport.send(media.reserve(item.file, fileSize: item.data.count, setID: setID))
            note(reserve.rateLimit)
            let reservation = try ScreenshotUploadRequests.reservation(in: reserve.data)
            for operation in reservation.operations {
                try await uploads.upload(operation, data: item.data) { _ in }
            }
            let checksum = ScreenshotPNG.checksum(item.data)
            try await note(transport.send(media.commit(id: reservation.id, checksum: checksum)).rateLimit)
            uploaded.append(reservation.id)
        }
        progress(media == .appPreviews
            ? String(localized: "Apple is processing the App Previews") : String(localized: "Apple is processing the screenshots"))
        processing()
        for (id, item) in zip(uploaded, files) {
            try await waitUntilProcessed(id, fileName: item.file.fileName, via: transport, sleep: sleep, note: note, interval: pollInterval)
        }
        try await delete(old, via: transport, note: note)
        try await note(transport.send(media.reorder(setID: setID, ids: uploaded)).rateLimit)
        return setID
    }

    @MainActor
    private func delete(_ ids: [String], via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws {
        for id in ids {
            do {
                try await note(transport.send(media.delete(id: id)).rateLimit)
            } catch AppStoreConnectError.notFound {
                // Already gone.
            }
        }
    }

    @MainActor
    private func waitUntilProcessed(
        _ id: String, fileName: String, via transport: any PushTransport, sleep: (Duration) async throws -> Void,
        note: (AppStoreConnectRateLimit?) -> Void, interval: () -> Duration
    ) async throws {
        var waited: Duration = .zero
        while true {
            let response = try await transport.fetch(media.statusPath(id: id))
            note(response.rateLimit)
            let state = ScreenshotUploadRequests.deliveryState(in: response.data)
            if state?.isComplete == true { return }
            if state?.isFailed == true {
                let details = state?.errors?.compactMap { $0.description ?? $0.code }.joined(separator: " ")
                throw ProductPageScreenshotsPushError.refused(fileName: fileName, details: details?.isEmpty == false ? details : nil)
            }
            guard waited < Self.timeout else { throw ProductPageScreenshotsPushError.timedOut(fileName: fileName) }
            let pause = interval()
            try await sleep(pause)
            waited += pause
        }
    }
}
