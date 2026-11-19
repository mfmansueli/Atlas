//
//  CustomProductPagesDocument.swift
//  Atlas
//

import Foundation

/// A page of `GET /v1/apps/{id}/appCustomProductPages?include=appCustomProductPageVersions`:
/// the pages, and their versions in `included`.
struct CustomProductPagesDocument: Decodable, Sendable {
    struct Linkage: Decodable, Sendable {
        var type: String
        var id: String
    }

    struct ToMany: Decodable, Sendable {
        var data: [Linkage]?
    }

    struct PageAttributes: Decodable, Sendable {
        var name: String?
        var url: String?
        var visible: Bool?
    }

    struct PageRelationships: Decodable, Sendable {
        var appCustomProductPageVersions: ToMany?
    }

    struct Page: Decodable, Sendable {
        var id: String
        var attributes: PageAttributes?
        var relationships: PageRelationships?

        var versionIDs: [String] {
            relationships?.appCustomProductPageVersions?.data?.map(\.id) ?? []
        }
    }

    struct VersionAttributes: Decodable, Sendable {
        var version: String?
        var state: String?
        var deepLink: String?
    }

    struct Included: Decodable, Sendable {
        var type: String
        var id: String
        var attributes: VersionAttributes?
    }

    var data: [Page]
    var included: [Included]?
    var links: AppStoreConnectPageLinks?

    /// The versions in `included`, by ID.
    var versions: [String: Included] {
        Dictionary((included ?? []).filter { $0.type == "appCustomProductPageVersions" }.map { ($0.id, $0) }) { first, _ in first }
    }
}
