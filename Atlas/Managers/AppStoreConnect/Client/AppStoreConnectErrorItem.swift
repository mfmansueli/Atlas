//
//  AppStoreConnectErrorItem.swift
//  Atlas
//

import Foundation

/// One entry of an `AppStoreConnectErrorResponse`, e.g. code
/// `NOT_AUTHORIZED` with a human-readable `detail`.
struct AppStoreConnectErrorItem: Decodable, Sendable {
    var status: String?
    var code: String?
    var title: String?
    var detail: String?
    /// The problems behind it, from `meta.associatedErrors` (resource path →
    /// errors). Apple sends `STATE_ERROR.ENTITY_STATE_INVALID` "This resource
    /// cannot be reviewed, please check associated errors to see why." with
    /// the real reasons only here: SimProps's Submit showed just that line.
    var associatedErrors: [AppStoreConnectErrorItem] = []
    /// For an associated error, the resource it's about, as Apple keys it:
    /// `/v1/appEvents/6740000000`.
    var resource: String?

    /// Its words: the detail, or the title without one.
    var text: String? {
        detail ?? title
    }

    /// The In-App Event an associated error is about, when its resource
    /// is one: `6740000000` of `/v1/appEvents/6740000000`.
    var eventID: String? {
        guard let resource, resource.hasPrefix("/v1/appEvents/") else { return nil }
        let id = resource.dropFirst("/v1/appEvents/".count).split(separator: "/").first.map(String.init)
        return id?.isEmpty == false ? id : nil
    }

    private enum CodingKeys: String, CodingKey {
        case status, code, title, detail, meta
    }

    private enum MetaKeys: String, CodingKey {
        case associatedErrors
    }

    /// Lenient: `meta` is free-form in Apple's spec, so a shape other than
    /// the usual one leaves the associated errors out, not the error.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        code = try? container.decodeIfPresent(String.self, forKey: .code)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        detail = try? container.decodeIfPresent(String.self, forKey: .detail)
        let meta = try? container.nestedContainer(keyedBy: MetaKeys.self, forKey: .meta)
        let byResource = (try? meta?.decodeIfPresent([String: [AppStoreConnectErrorItem]].self, forKey: .associatedErrors)) ?? [:]
        associatedErrors = byResource.sorted { $0.key < $1.key }.flatMap { resource, items in
            items.map { item in
                var item = item
                item.resource = resource
                return item
            }
        }
    }
}
