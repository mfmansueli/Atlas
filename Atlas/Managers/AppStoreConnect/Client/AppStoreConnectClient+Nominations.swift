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
    /// When Apple refuses a parameter of the full query (400
    /// `PARAMETER_ERROR`), it's read again with `nominationsPlainQuery`:
    /// the same nominations and links, without names.
    func nominations(state: String, appID: String) async throws -> [NominationsDocument] {
        do {
            return try await nominationPages(Self.nominationsQuery(state: state, appID: appID))
        } catch let error as AppStoreConnectError where Self.isParameterError(error) {
            return try await nominationPages(Self.nominationsPlainQuery(state: state, appID: appID))
        }
    }

    /// The query of `nominations(state:appID:)`: `filter[state]` is
    /// required by Apple. Actors come whole: Apple's server refuses
    /// `fields[actors]=actorType` (PARAMETER_ERROR.INVALID, 24 Nov 2026)
    /// although the 4.6.1 spec lists it, and an actor is five short strings.
    static func nominationsQuery(state: String, appID: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "filter[state]", value: state),
            URLQueryItem(name: "filter[relatedApps]", value: appID),
            URLQueryItem(name: "include", value: "relatedApps,inAppEvents,supportedTerritories,createdByActor,submittedByActor"),
            URLQueryItem(name: "fields[apps]", value: "name"),
            URLQueryItem(name: "fields[appEvents]", value: "referenceName"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "limit[relatedApps]", value: "50"),
            URLQueryItem(name: "limit[inAppEvents]", value: "50"),
            URLQueryItem(name: "limit[supportedTerritories]", value: "200"),
        ]
    }

    /// The second try after a refused parameter: no sparse fieldsets and no
    /// actors, but still the apps, events and territories each nomination
    /// links to. Without them an update would clear what the draft has.
    static func nominationsPlainQuery(state: String, appID: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "filter[state]", value: state),
            URLQueryItem(name: "filter[relatedApps]", value: appID),
            URLQueryItem(name: "include", value: "relatedApps,inAppEvents,supportedTerritories"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "limit[relatedApps]", value: "50"),
            URLQueryItem(name: "limit[inAppEvents]", value: "50"),
            URLQueryItem(name: "limit[supportedTerritories]", value: "200"),
        ]
    }

    /// The app's drafts, to find one by name when a Submit's Create went in
    /// an earlier push. Whole attributes, no sparse fieldset: the drafts
    /// are few, and Apple's server has refused field names its spec lists.
    static func draftNominationsPath(appID: String) -> String {
        "/v1/nominations?filter%5Bstate%5D=DRAFT&filter%5BrelatedApps%5D=\(appID)&limit=200"
    }

    /// 400 `PARAMETER_ERROR`, e.g. `PARAMETER_ERROR.INVALID`: Apple
    /// refused a query parameter, not the account or the app.
    static func isParameterError(_ error: AppStoreConnectError) -> Bool {
        guard case let .server(statusCode, code, _) = error else { return false }
        return statusCode == 400 && (code ?? "").hasPrefix("PARAMETER_ERROR")
    }

    private func nominationPages(_ query: [URLQueryItem]) async throws -> [NominationsDocument] {
        var pages: [NominationsDocument] = []
        var next: URL? = url("/v1/nominations", query: query)
        while let pageURL = next {
            let page: NominationsDocument = try await get(pageURL)
            pages.append(page)
            next = page.links?.next
        }
        return pages
    }
}
