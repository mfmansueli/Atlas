//
//  PricingServices.swift
//  Atlas
//

import Foundation

/// What the Subscription Pricing section needs from outside itself. `LivePricingServices`
/// talks to App Store Connect; tests and DEBUG scenes use canned data.
@MainActor
protocol PricingServices {
    /// The numbers the overview cards and the sidebar show for one app.
    func summary(for app: StoreApp) async throws -> PricingSummary

    /// The app's subscription groups and in-app purchases, with base prices.
    func catalog(for app: StoreApp) async throws -> PricingCatalog

    /// One product's prices in every territory, with equalized prices and
    /// whatever ladders and sales evidence are already at hand.
    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet

    /// Apple's price point ladders for a few territories, by territory ID.
    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder]

    /// When Apple's price points kept for the product were read, by
    /// territory (get_prices' grid); empty when the services keep none.
    func ladderReadDates(for productID: String, commission: Commission) -> [String: Date]

    /// Drops the product's kept ladders read before `date`: a push changed
    /// its prices then, so the next suggestions stand on points read after.
    func forgetLadders(for productID: String, fetchedBefore date: Date) async

    /// The price indices strategies draw on: the bundled snapshot, plus any
    /// custom index the scene starts with.
    func indexSnapshot() -> PriceIndexSnapshot

    /// A subscription's offers: introductory, promotional, win-back and
    /// offer codes.
    func offers(for product: PricingProduct) async throws -> [SubscriptionOffer]

    /// Existing subscribers per territory, for the schedule's consent
    /// warnings; nil when Atlas can't read them.
    func subscribers(for product: PricingProduct) async throws -> [String: Int]?

    /// Each territory's sales in the 28 days either side of a price change
    /// on `date`, for Results; nil when Atlas can't read sales.
    func salesComparison(for product: PricingProduct, territoryIDs: [String], changedOn date: Date) async throws -> [String: SalesComparison]?

    /// The product's price changes, pushed by Atlas or read from App Store
    /// Connect, newest first, for Results.
    func priceHistory(for product: PricingProduct) -> [PriceChangeRecord]
}
