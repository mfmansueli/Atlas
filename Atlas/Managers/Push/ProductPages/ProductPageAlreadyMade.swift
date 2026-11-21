//
//  ProductPageAlreadyMade.swift
//  Atlas
//

import Foundation

/// A new custom product page whose name App Store Connect already has: an
/// earlier push made it although Apple answered with an error (on Alba,
/// `UNEXPECTED_ERROR` after 60 s, the page there minutes later). Making it
/// again would fail the same way or make a second one, so it isn't sent;
/// the page's own screenshots still go into the page of that name.
struct ProductPageAlreadyMade: LocalizedError, Equatable {
    var name: String

    var errorDescription: String? {
        String(localized: """
        “\(name)” is already in App Store Connect, from an earlier push. Open Custom Product Pages: Atlas turns the draft \
        into that page and queues what it still needs.
        """)
    }

    /// The page name a `POST /v1/appCustomProductPages` makes; nil for any
    /// other request.
    static func name(creating request: PushRequest) -> String? {
        guard request.method == .post, request.path == "/v1/appCustomProductPages", let body = request.body else { return nil }
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        let attributes = (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        return attributes?["name"] as? String
    }

    /// Throws when `request` makes a page App Store Connect already has.
    @MainActor
    static func check(
        _ request: PushRequest, appID: StoreApp.ID, transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        guard let name = name(creating: request) else { return }
        let pages = try await transport.fetch(ProductPageScreenshotsPush.pagesPath(appID: appID))
        note(pages.rateLimit)
        if ProductPageScreenshotsPush.pageID(named: name, in: pages.data) != nil { throw ProductPageAlreadyMade(name: name) }
    }
}
