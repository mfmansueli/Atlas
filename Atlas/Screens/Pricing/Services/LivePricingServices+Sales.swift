//
//  LivePricingServices+Sales.swift
//  Atlas
//

import Foundation

/// Results, the schedule's consent warnings and the price history, from
/// what Analytics already downloaded (`LivePricingSales`).
extension LivePricingServices {
    /// Active subscriptions per territory on the newest day Sales and
    /// Trends' Subscription report has; nil when sales can't be read.
    func subscribers(for product: PricingProduct) async throws -> [String: Int]? {
        sales.subscribers(for: product, baseTerritoryID: baseTerritoryID)
    }

    /// Each territory's 28 days either side of a change on `date`; nil
    /// when sales can't be read.
    func salesComparison(for product: PricingProduct, territoryIDs: [String], changedOn date: Date) async throws -> [String: SalesComparison]? {
        sales.comparison(for: product, territoryIDs: territoryIDs, changedOn: date, baseTerritoryID: baseTerritoryID)
    }

    func priceHistory(for product: PricingProduct) -> [PriceChangeRecord] {
        sales.priceHistory(for: product)
    }
}
