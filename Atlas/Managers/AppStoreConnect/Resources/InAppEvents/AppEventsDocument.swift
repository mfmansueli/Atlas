//
//  AppEventsDocument.swift
//  Atlas
//

import Foundation

/// A page of `appEvents` with their localizations included.
struct AppEventsDocument: Decodable, Sendable {
    struct Relationships: Decodable, Sendable {
        var localizations: ToMany?
    }

    struct ToMany: Decodable, Sendable {
        var data: [AppInformationLinkage.Identifier]?
    }

    struct Event: Decodable, Sendable {
        var id: String
        var attributes: AppEventAttributes
        var relationships: Relationships?

        var localizationIDs: [String] {
            relationships?.localizations?.data?.map(\.id) ?? []
        }
    }

    var data: [Event]
    var included: [AppStoreConnectResource<AppEventLocalizationAttributes>]?
    var links: AppStoreConnectPageLinks?
}
