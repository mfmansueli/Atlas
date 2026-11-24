//
//  NominationsDocument.swift
//  Atlas
//

import Foundation

/// A page of `GET /v1/nominations` with what they name included: the apps,
/// In-App Events and territories, and who created or submitted each one
/// (`actors`).
struct NominationsDocument: Decodable, Sendable {
    struct Resource: Decodable, Sendable {
        var id: String
        var attributes: NominationAttributes
        var relationships: Relationships?
    }

    struct Relationships: Decodable, Sendable {
        var relatedApps: ToMany?
        var inAppEvents: ToMany?
        var supportedTerritories: ToMany?
        var createdByActor: ToOne?
        var submittedByActor: ToOne?
    }

    struct ToMany: Decodable, Sendable {
        var data: [AppInformationLinkage.Identifier]?

        var ids: [String] { data?.map(\.id) ?? [] }
    }

    struct ToOne: Decodable, Sendable {
        var data: AppInformationLinkage.Identifier?
    }

    /// One included resource: an app, event, territory or actor. Only what
    /// Atlas shows is read.
    struct Included: Decodable, Sendable {
        var type: String
        var id: String
        var attributes: NominationIncludedAttributes?

        /// An actor's name as Atlas writes it: the person's first name,
        /// "API key 2X9R4HXF34", "Xcode Cloud" or "Apple".
        var actorName: String? {
            guard type == "actors", let attributes else { return nil }
            if let first = attributes.userFirstName, !first.isEmpty { return first }
            if let last = attributes.userLastName, !last.isEmpty { return last }
            if let key = attributes.apiKeyId, !key.isEmpty { return String(localized: "API key \(key)", comment: "kind:other") }
            switch attributes.actorType {
            case "XCODE_CLOUD": return "Xcode Cloud"
            case "APPLE": return "Apple"
            default: return nil
            }
        }
    }

    var data: [Resource]
    var included: [Included]?
    var links: AppStoreConnectPageLinks?
}
