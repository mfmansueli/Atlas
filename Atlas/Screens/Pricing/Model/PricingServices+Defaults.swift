//
//  PricingServices+Defaults.swift
//  Atlas
//

import Foundation

/// Fallbacks for services that only feed the overview, such as the test
/// doubles that count summary fetches: they have no catalog to price. The
/// live services use the offers one too; they read subscribers, sales and
/// the price history from what Analytics downloaded.
extension PricingServices {
    func catalog(for _: StoreApp) async throws -> PricingCatalog {
        .empty
    }

    func priceSheet(for product: PricingProduct, commission _: Commission) async throws -> ProductPriceSheet {
        throw AppStoreConnectError.notFound(detail: String(localized: "No prices for \(product.name)."))
    }

    func ladders(for _: PricingProduct, territoryIDs _: [String], commission _: Commission) async throws -> [String: PricePointLadder] {
        [:]
    }

    /// Services that keep no ladders can't say when they were read.
    func ladderReadDates(for _: String, commission _: Commission) -> [String: Date] {
        [:]
    }

    /// Services that keep no ladders have nothing to drop.
    func forgetLadders(for _: String, fetchedBefore _: Date) async {}

    /// The snapshot bundled with the app.
    func indexSnapshot() -> PriceIndexSnapshot {
        (try? PriceIndexSnapshot.bundled()) ?? .empty
    }

    /// Offers aren't read from App Store Connect yet.
    func offers(for _: PricingProduct) async throws -> [SubscriptionOffer] {
        []
    }

    /// No subscriber counts without Sales and Trends.
    func subscribers(for _: PricingProduct) async throws -> [String: Int]? {
        nil
    }

    /// No results without Sales and Trends and App Analytics.
    func salesComparison(for _: PricingProduct, territoryIDs _: [String], changedOn _: Date) async throws -> [String: SalesComparison]? {
        nil
    }

    /// No price history: Results compare pushes alone.
    func priceHistory(for _: PricingProduct) -> [PriceChangeRecord] {
        []
    }
}
