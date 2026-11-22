//
//  PushPagedRead.swift
//  Atlas
//

import Foundation

/// The reads a purchase setup step makes while pushing: every page's
/// `data` and `included`, following `links.next`, and the small helpers to
/// pick a resource's attributes and relationships out of them.
enum PushPagedRead {
    /// Every page's `data`, then every page's `included`.
    @MainActor
    static func resources(
        at path: String,
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> (data: [[String: Any]], included: [[String: Any]]) {
        var next: String? = path
        var data: [[String: Any]] = []
        var included: [[String: Any]] = []
        while let page = next {
            let response = try await transport.fetch(page)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            data += object?["data"] as? [[String: Any]] ?? []
            included += object?["included"] as? [[String: Any]] ?? []
            next = (object?["links"] as? [String: Any])?["next"] as? String
        }
        return (data, included)
    }

    /// `relationships.<name>.data.id`.
    static func relationshipID(_ name: String, of resource: [String: Any]) -> String? {
        let relationships = resource["relationships"] as? [String: Any]
        return ((relationships?[name] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String
    }

    /// `attributes.customerPrice` as a number.
    static func customerPrice(of resource: [String: Any]) -> Decimal? {
        let attributes = resource["attributes"] as? [String: Any]
        return (attributes?["customerPrice"] as? String).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    /// The prices just below and above `price` among `resources`.
    static func nearest(_ price: Decimal, in resources: [[String: Any]]) -> [Decimal] {
        let prices = resources.compactMap(customerPrice(of:)).sorted()
        return [prices.last { $0 < price }, prices.first { $0 > price }].compactMap(\.self)
    }

    /// A `{…}` body as a request.
    static func request(_ method: PushRequest.Method, _ path: String, _ body: [String: Any]) -> PushRequest {
        let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return PushRequest(method: method, path: path, body: data)
    }

    /// The request's JSON body.
    static func body(of request: PushRequest) -> [String: Any]? {
        request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}
