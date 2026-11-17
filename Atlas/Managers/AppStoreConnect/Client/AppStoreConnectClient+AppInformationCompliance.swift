//
//  AppStoreConnectClient+AppInformationCompliance.swift
//  Atlas
//

import Foundation

// App Compliance's reads: where the app is sold and what Apple finds
// missing in each country or region. Apple's API has no resource for the
// trader status, the ICP Filing Number, the Vietnam game license or the
// medical device declaration, so those are never read or written; taking
// a country off sale is a `PushRequest` queued as a pending change.
extension AppStoreConnectClient {
    /// The app's availability resource; nil before it has countries and
    /// regions (`GET /v1/apps/{id}/appAvailabilityV2`).
    func appAvailabilityID(appID: String) async throws -> String? {
        let query = [URLQueryItem(name: "fields[appAvailabilities]", value: "availableInNewTerritories")]
        do {
            let document: AppInformationResourceDocument<AppAvailabilityAttributes> = try await get(
                url("/v1/apps/\(appID)/appAvailabilityV2", query: query)
            )
            return document.data?.id
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// Every country and region with whether the app is sold there, Apple's
    /// statuses and the territory's linkage
    /// (`GET /v2/appAvailabilities/{id}/territoryAvailabilities`).
    func territoryAvailabilities(
        availabilityID: String
    ) async throws -> [AppInformationResourceDocument<TerritoryAvailabilityAttributes>.Resource] {
        let query = [
            URLQueryItem(name: "fields[territoryAvailabilities]", value: "available,contentStatuses,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        var next: URL? = url("/v2/appAvailabilities/\(availabilityID)/territoryAvailabilities", query: query)
        var resources: [AppInformationResourceDocument<TerritoryAvailabilityAttributes>.Resource] = []
        while let pageURL = next {
            let page: AppStoreConnectLinkedPage<TerritoryAvailabilityAttributes> = try await get(pageURL)
            resources += page.data
            next = page.links?.next
        }
        return resources
    }
}
