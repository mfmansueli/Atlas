//
//  PricingDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state a Pricing DEBUG scene opens in, reached through the same view
/// model calls a person's clicks make: filters, selection, applied prices,
/// the inspector, an open popover or sheet, and the product page's tab and
/// view shown.
struct PricingDebugLaunch {
    /// Opens on the product cards instead of the selected product's page.
    var showsProducts = false
    /// Opens a product's page over the cards (board 73, `pr-prod*`).
    var productPage: PricingProductRoute?
    /// The product page's Details can't read availability and Family Sharing.
    var failsProductFacts = false
    /// Selects this product instead of the default one.
    var productID: String?
    /// Prices by Country's Filters.
    var filters: PricesByCountryFilters?
    /// Territories (alpha-3) whose suggestion is applied.
    var appliedSuggestions: [String] = []
    /// Follow the strategy everywhere, as Apply Recommended Prices… does, without opening review.
    var follows = false
    /// Hand-set prices by territory (alpha-3).
    var manualPrices: [String: Decimal] = [:]
    var strategy: PricingStrategy?
    /// Countries (alpha-3) selected in Prices by Country.
    var selection: [String] = []
    /// Opens Customize Suggestions….
    var showsInspector = false
    var collapsedSections: Set<StrategyInspectorSection> = []
    /// Opens the custom index import sheet with the sample CSV.
    var showsImport = false
    /// Refreshes once loaded, as ⌘R does.
    var refreshes = false
    /// The product page's tab.
    var productTab: PricingProductTab?
    /// Table, Map or Histogram.
    var display: PricingDisplay?
    /// The schedule queued changes follow.
    var schedule: PriceSchedule?
    /// Opens the schedule sheet.
    var showsSchedule = false
    /// Selects this offer on the Offers tab.
    var offerID: SubscriptionOffer.ID?
    /// Pins today, for Results' 28 days and the schedule's earliest date.
    var today: Date?
    /// Opens a purchase setup sheet.
    var sheet: PricingDebugSheet?
    /// Where Lumen's review screenshots are (`rs-*`).
    var reviewShots: ReviewShotsDebugState?
    /// Lumen Monthly has a promotional offer, a win-back offer and an
    /// offer code in App Store Connect (`SubscriptionOffersSampleData`).
    var hasSampleOffers = false
    /// Opens an offer sheet on Lumen Monthly.
    var offerSheet: SubscriptionOfferDebugSheet?
    /// Opens an offer code sheet on Lumen Lifetime.
    var inAppPurchaseOfferSheet: InAppPurchaseOfferCodeDebugSheet?
    /// "Preview in"'s country (alpha-3).
    var previewTerritoryID: String?
    /// Opens "Preview in"'s country menu.
    var opensPreviewMenu = false
    /// Opens a country's price as Analytics' finding or a Reviews theme
    /// does (alpha-2, `.showTerritoryPrice`).
    var analyticsTerritory: String?
    /// Queues Create In-App Purchase's defaults, without a review screenshot.
    var queuesNewInAppPurchase = false
    /// A strategy an assistant suggested, waiting at the top
    /// (`pr-strategy`).
    var strategySuggestion: PricingStrategySuggestion?
    /// What Prices by Country opens with (`pr-prod-*`).
    var countries: PricesByCountryDebugLaunch?
    /// Lumen Plus Annual's price tests (board 76, `pt-*`).
    var priceTests: PriceTestDebugLaunch?
}
#endif
