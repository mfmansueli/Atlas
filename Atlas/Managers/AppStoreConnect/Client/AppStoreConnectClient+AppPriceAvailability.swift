//
//  AppStoreConnectClient+AppPriceAvailability.swift
//  Atlas
//

import Foundation

// Pricing's reads for the app itself, as App Store Connect's Pricing and
// Availability page shows them: its price schedule and Apple's price
// points, and the countries and regions it's sold in. Every write is a
// `PushRequest` queued as a pending change.
extension AppStoreConnectClient {
    /// `GET /v1/apps/{id}/appPriceSchedule` with its base territory; nil
    /// when the app has never had a price (404).
    func appPriceSchedule(appID: String) async throws -> AppPriceScheduleDocument? {
        do {
            return try await get(url("/v1/apps/\(appID)/appPriceSchedule", query: [
                URLQueryItem(name: "include", value: "baseTerritory"),
                URLQueryItem(name: "fields[territories]", value: "currency"),
            ]))
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// `GET /v1/appPriceSchedules/{id}/manualPrices` with each price's point
    /// and territory, every page.
    func appPrices(scheduleID: String) async throws -> PricingAPIDocument<AppPriceAttributes> {
        try await pricingPages(of: "/v1/appPriceSchedules/\(scheduleID)/manualPrices", query: [
            URLQueryItem(name: "include", value: "appPricePoint,territory"),
            URLQueryItem(name: "fields[appPrices]", value: "manual,startDate,endDate,appPricePoint,territory"),
            URLQueryItem(name: "fields[appPricePoints]", value: "customerPrice,proceeds,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    /// `GET /v1/apps/{id}/appPricePoints` in one territory: every price the
    /// app can have there, Free (0) among them.
    func appPricePoints(appID: String, territoryID: String) async throws -> PricingAPIDocument<SubscriptionPricePointAttributes> {
        try await pricingPages(of: "/v1/apps/\(appID)/appPricePoints", query: [
            URLQueryItem(name: "filter[territory]", value: territoryID),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "fields[appPricePoints]", value: "customerPrice,proceeds,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    /// The app's availability with whether new countries get it; nil before
    /// it has one (`GET /v1/apps/{id}/appAvailabilityV2`, 404).
    func appAvailability(appID: String) async throws -> AppInformationResourceDocument<AppAvailabilityAttributes>.Resource? {
        let query = [URLQueryItem(name: "fields[appAvailabilities]", value: "availableInNewTerritories")]
        do {
            let document: AppInformationResourceDocument<AppAvailabilityAttributes> = try await get(
                url("/v1/apps/\(appID)/appAvailabilityV2", query: query)
            )
            return document.data
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// Every country and region of the availability, with whether the app
    /// is sold there, its release date and pre-order
    /// (`GET /v2/appAvailabilities/{id}/territoryAvailabilities`).
    func saleTerritoryAvailabilities(
        availabilityID: String
    ) async throws -> [AppInformationResourceDocument<TerritoryAvailabilityAttributes>.Resource] {
        let query = [
            URLQueryItem(name: "fields[territoryAvailabilities]", value: "available,releaseDate,preOrderEnabled,contentStatuses,territory"),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
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

    /// Every country and region the App Store has (`GET /v1/territories`).
    func territories() async throws -> [AppStoreConnectResource<TerritoryAttributes>] {
        try await allPages(of: "/v1/territories", query: [
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }
}
