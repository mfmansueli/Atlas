//
//  AppStoreConnectClient+InAppPurchasePricing.swift
//  Atlas
//

import Foundation

/// The reads Pricing makes for an in-app purchase's prices, which Atlas
/// shows and doesn't change: its schedule, the manual and automatic prices
/// under it, and Apple's price points.
extension AppStoreConnectClient {
    /// `GET /v2/inAppPurchases/{id}/iapPriceSchedule` with its base
    /// territory; nil when the purchase has never had a price (404).
    func inAppPurchasePriceSchedule(purchaseID: String) async throws -> InAppPurchasePriceScheduleDocument? {
        let scheduleURL = url("/v2/inAppPurchases/\(purchaseID)/iapPriceSchedule", query: [
            URLQueryItem(name: "include", value: "baseTerritory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
        ])
        do {
            return try await readRetry.run { try await get(scheduleURL) }
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// `GET /v1/inAppPurchasePriceSchedules/{id}/manualPrices` (or
    /// `automaticPrices`) with each price's point and territory, every page;
    /// only `territoryID`'s when given (`filter[territory]`, API 4.6).
    func inAppPurchasePrices(
        scheduleID: String, automatic: Bool, territoryID: String? = nil
    ) async throws -> PricingAPIDocument<InAppPurchasePriceAttributes> {
        var query = [
            URLQueryItem(name: "include", value: "inAppPurchasePricePoint,territory"),
            URLQueryItem(name: "fields[inAppPurchasePricePoints]", value: "customerPrice,proceeds,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        if let territoryID { query.append(URLQueryItem(name: "filter[territory]", value: territoryID)) }
        return try await pricingPages(of: "/v1/inAppPurchasePriceSchedules/\(scheduleID)/\(automatic ? "automaticPrices" : "manualPrices")", query: query)
    }

    /// `GET /v1/inAppPurchasePricePoints/{id}/equalizations`: the point in
    /// every other territory Apple equalizes with this one. In-app purchase
    /// points have no `proceedsYear2`, so it stays nil.
    func inAppPurchaseEqualizations(pricePointID: String) async throws -> PricingAPIDocument<SubscriptionPricePointAttributes> {
        try await pricingPages(of: "/v1/inAppPurchasePricePoints/\(pricePointID)/equalizations", query: [
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "fields[inAppPurchasePricePoints]", value: "customerPrice,proceeds,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    /// `GET /v2/inAppPurchases/{id}/pricePoints` for a few territories:
    /// Apple's full ladder of prices there.
    func inAppPurchasePricePoints(purchaseID: String, territoryIDs: [String]) async throws -> PricingAPIDocument<SubscriptionPricePointAttributes> {
        try await pricingPages(of: "/v2/inAppPurchases/\(purchaseID)/pricePoints", query: [
            URLQueryItem(name: "filter[territory]", value: territoryIDs.joined(separator: ",")),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "fields[inAppPurchasePricePoints]", value: "customerPrice,proceeds,territory"),
            URLQueryItem(name: "fields[territories]", value: "currency"),
            URLQueryItem(name: "limit", value: "8000"),
        ])
    }
}
