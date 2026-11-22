//
//  ProductPageAlreadyMade.swift
//  Atlas
//

import Foundation

/// A new custom product page whose name App Store Connect already has
/// before this change sent anything: another push (or a person in App Store
/// Connect) made it. Making it again would fail the same way or make a
/// second one, so it isn't sent; the page's own screenshots still go into
/// the page of that name. A page this change's own create may have made
/// (`PushItem.mayHaveMadePage`) is taken instead (`ProductPageCreate`).
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
}
