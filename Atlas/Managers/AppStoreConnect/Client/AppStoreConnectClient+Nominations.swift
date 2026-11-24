//
//  AppStoreConnectClient+Nominations.swift
//  Atlas
//

import Foundation

/// Nominations (App Store Connect API 4.6.1): what the account told Apple's
/// editors about. Reads only; creating, editing, submitting, archiving and
/// deleting are built by `NominationChangeBuilder` and sent by Review & Push.
extension AppStoreConnectClient {
    /// The states `GET /v1/nominations` must be filtered by, one read each.
    static let nominationStates = ["DRAFT", "SUBMITTED", "ARCHIVED"]

    /// One state's nominations that include the app, with their apps,
    /// events, territories and people (`GET /v1/nominations?filter[state]=…`).
    func nominations(state: String, appID: String) async throws -> [NominationsDocument] {
        var pages: [NominationsDocument] = []
        var next: URL? = url("/v1/nominations", query: Self.nominationsQuery(state: state, appID: appID))
        while let pageURL = next {
            let page: NominationsDocument = try await get(pageURL)
            pages.append(page)
            next = page.links?.next
        }
        return pages
    }

    /// The query of `nominations(state:appID:)`: `filter[state]` is
    /// required by Apple.
    static func nominationsQuery(state: String, appID: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "filter[state]", value: state),
            URLQueryItem(name: "filter[relatedApps]", value: appID),
            URLQueryItem(name: "include", value: "relatedApps,inAppEvents,supportedTerritories,createdByActor,submittedByActor"),
            URLQueryItem(name: "fields[apps]", value: "name"),
            URLQueryItem(name: "fields[appEvents]", value: "referenceName"),
            URLQueryItem(name: "fields[actors]", value: "actorType,userFirstName,userLastName,apiKeyId"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "limit[relatedApps]", value: "50"),
            URLQueryItem(name: "limit[inAppEvents]", value: "50"),
            URLQueryItem(name: "limit[supportedTerritories]", value: "200"),
        ]
    }
}
