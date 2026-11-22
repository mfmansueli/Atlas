//
//  ProductPagePushState.swift
//  Atlas
//

import Foundation

/// What one push learns about custom product pages, so a page's changes
/// share it: each page's version that takes edits (found or made once,
/// even when its screenshots go out side by side), and the App Store
/// Connect IDs of pages made in Atlas.
@MainActor
final class ProductPagePushState {
    /// Each page's version that takes edits, by page ID.
    var versions: [String: String] = [:]
    /// A version being found or made: the page's other changes wait for it
    /// instead of making another.
    private var finding: [String: Task<String, any Error>] = [:]
    /// Pages made in Atlas, by draft ID.
    private var pageIDs: [String: String] = [:]

    func reset() {
        versions = [:]
        finding = [:]
        pageIDs = [:]
    }

    /// The language a page's screenshots go into: in the page's version
    /// that takes edits, made when the version hasn't it.
    func localization(
        for screenshots: ProductPageScreenshotsPush, made: String?, transport: any PushTransport,
        note: @escaping (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        let content = screenshots.content
        let pageID = try await pageID(of: screenshots, made: made, transport: transport, note: note)
        let versionID = try await version(pageID: pageID, deepLink: content.currentDeepLink, transport: transport, note: note)
        let write = ProductPageLocaleWrite(.init(pageID: pageID, currentDeepLink: content.currentDeepLink, locale: content.locale))
        let sent = try await write.send(via: transport, knownVersionID: versionID)
        note(sent.rateLimit)
        guard let localizationID = sent.localizationID else { throw AppStoreConnectError.unexpectedPayload }
        return localizationID
    }

    /// Sends a page write into the page's version known in this push, and
    /// keeps the version. After a server failure or no answer it's sent
    /// once more, after `pause`: it reads the version and the language
    /// again first, so nothing is made twice (a language made meanwhile is
    /// refused as a duplicate and written into instead).
    func send(
        _ write: ProductPageLocaleWrite, transport: any PushTransport, pause: Duration, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> (versionID: String, localizationID: String?) {
        let sent: (versionID: String, localizationID: String?, rateLimit: AppStoreConnectRateLimit?)
        do {
            sent = try await write.send(via: transport, knownVersionID: versions[write.pageID])
        } catch where PushController.mayHaveGoneThrough(error) {
            try await Task.sleep(for: pause)
            sent = try await write.send(via: transport, knownVersionID: versions[write.pageID])
        }
        versions[write.pageID] = sent.versionID
        note(sent.rateLimit)
        return (sent.versionID, sent.localizationID)
    }

    /// The page's version that takes edits, found or made once in this push.
    func version(
        pageID: String, deepLink: String?, transport: any PushTransport, note: @escaping (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        if let known = versions[pageID] { return known }
        if let task = finding[pageID] { return try await task.value }
        let write = ProductPageLocaleWrite(.init(pageID: pageID, currentDeepLink: deepLink))
        let task = Task { @MainActor () throws -> String in
            let sent = try await write.send(via: transport, knownVersionID: nil)
            note(sent.rateLimit)
            return sent.versionID
        }
        finding[pageID] = task
        do {
            let versionID = try await task.value
            versions[pageID] = versionID
            return versionID
        } catch {
            finding[pageID] = nil
            throw error
        }
    }

    /// The page's App Store Connect ID: a draft's is the one its own change
    /// made in this push (`made`), else the page of its name.
    func pageID(
        of screenshots: ProductPageScreenshotsPush, made: String?, transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        let content = screenshots.content
        guard screenshots.needsPageID else { return content.pageID }
        if let known = pageIDs[content.pageID] ?? made {
            pageIDs[content.pageID] = known
            return known
        }
        let pages = try await transport.fetch(ProductPageScreenshotsPush.pagesPath(appID: content.appID))
        note(pages.rateLimit)
        guard let id = ProductPageScreenshotsPush.pageID(named: content.pageName, in: pages.data) else {
            throw ProductPageScreenshotsPushError.pageMissing(name: content.pageName)
        }
        pageIDs[content.pageID] = id
        return id
    }
}
