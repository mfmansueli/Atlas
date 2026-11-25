//
//  PricingDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Subscription Pricing section's DEBUG scenes (`-AtlasDebugScene <id>`),
/// as the design's Pricing and Customize boards show them. `DebugSceneView`
/// asks here for any id it doesn't know itself.
///
/// - `mode-sheet`: Lumen Journal's first visit, asking for a pricing mode.
/// Scenes with a launch open on the selected product's page (board 73)
/// unless they show the product cards.
///
/// - `pricing-keep`: Tempo Metronome with Keep my prices, Europe only.
/// - `pricing-suggest`, `pricing-breakdown`: Lumen Annual with Brazil's
///   price popover, or after three suggestions accepted.
/// - `pricing-applied`: every territory filled, Germany set by hand.
/// - `pricing-bulk`: four Asia Pacific rows selected.
/// - `pricing-nosales`: a key whose role can't read sales.
/// - `pricing-skeleton`: the skeleton during a refresh that never ends.
/// - `pricing-refresh`: a refresh (as after a push) whose prices arrive after
///   two seconds of skeleton.
/// - `pricing-nosubs`: Quiet Timer, which has nothing to price.
/// - `price-br`: Brazil's price opened from Analytics or Reviews: the
///   product cards with "Preview in" on Brazil.
/// - `pr-newsub-noshot`: a new in-app purchase waiting in Review & Push
///   without its review screenshot.
/// - `iap`: Lumen Lifetime, an in-app purchase.
/// - `custom`, `custom-tune`, `custom-csv`: Customize Suggestions… with a
///   Big Mac strategy, its limits and exclusions, and a CSV import waiting
///   for confirmation.
/// - `pricing-map`, `pricing-hist`: every territory filled, as the map or
///   as the histogram.
/// - `schedule`: the schedule sheet for a strategy that allows premiums, with
///   the increases' existing subscribers.
/// - `results`, `results-waiting`: Lumen Annual's Oct 26 push four weeks
///   later, or on its first day.
/// - `offers`: Lumen Annual's promotional offer.
/// - `pricing-products`: the Prices page's card per product, with their
///   suggestions and "Preview in".
/// - `pr-prev`, `pr-prev-menu`: "Preview in" on Brazil, where Annual's
///   price waits in Review & Push and Monthly's is suggested; or with its
///   country menu open.
/// - `pr-prev-loading`: the product cards while no price has arrived, with
///   "Preview in" in grey.
/// - `new-iap`: Create In-App Purchase over Lumen's cards.
/// - `intro-offer`: Add Introductory Offer… for Lumen Monthly.
/// - `review-screenshot`: Review Screenshot… for Lumen Lifetime.
/// - `offers-all`: Lumen Monthly's Offers tab with a promotional offer, a
///   win-back offer and an offer code (its custom code and one-time codes)
///   from App Store Connect, the offer code selected.
/// - `promo-offer`, `promo-prices`, `winback-offer`, `winback-edit`,
///   `offer-code`, `offer-code-custom`, `offer-code-batch`: New Promotional
///   Offer…, Change Prices…, New Win-Back Offer…, Edit…, New Offer Code…,
///   Add Custom Code… and Add One-Time Codes… on Lumen Monthly
///   (`SubscriptionOfferDebugSheet`).
/// - `iap-offers`: Lumen Lifetime's Offers tab with an offer code (its
///   custom code and one-time codes) from App Store Connect, selected.
/// - `iap-offer-code`, `iap-offer-code-custom`, `iap-offer-code-batch`: New
///   Offer Code…, Add Custom Code… and Add One-Time Codes… on Lumen Lifetime
///   (`InAppPurchaseOfferCodeDebugSheet`).
/// - `rs-match`, `rs-none`, `rs-run`, `rs-arrived`, `rs-preview`,
///   `rs-fail-nav`, `rs-fail-price`, `rs-accepted`, `rs-skipped`,
///   `rs-size`, `rs-live`: Lumen's App Review
///   screenshots made for the person (`ReviewShotsDebugState`).
enum PricingDebugScenes {
    typealias AppIDs = DebugFixtures.AppID

    static let ids = [
        "mode-sheet", "pricing-keep", "pricing-suggest", "pricing-breakdown", "pricing-applied", "pricing-bulk",
        "pricing-nosales", "pricing-skeleton", "pricing-refresh", "pricing-nosubs", "iap", "price-br", "pr-newsub-noshot",
        "custom", "custom-tune", "custom-csv",
        "pricing-map", "pricing-hist", "schedule", "results", "results-waiting", "offers",
        "pricing-products", "pr-prev", "pr-prev-menu", "pr-prev-loading", "new-iap", "intro-offer", "review-screenshot", "offers-all", "iap-offers",
    ] + ReviewShotsDebugState.allCases.map(\.sceneID) + SubscriptionOfferDebugSheet.allCases.map(\.sceneID)
        + InAppPurchaseOfferCodeDebugSheet.allCases.map(\.sceneID)

    @MainActor
    static func view(for id: String) -> AnyView? {
        pricingScene(id) ?? stateScene(id) ?? customizeScene(id) ?? viewScene(id) ?? setupScene(id)
    }

    @MainActor
    private static func pricingScene(_ id: String) -> AnyView? {
        switch id {
        case "mode-sheet":
            scene(pricingModes: DebugWorkspace.pricingModes.filter { $0.key != AppIDs.lumen })
        case "pricing-keep":
            scene(app: AppIDs.tempo, launch: PricingDebugLaunch(filters: PricesByCountryFilters(regions: [.europe])))
        case "pricing-products":
            scene(launch: PricingDebugLaunch(showsProducts: true))
        case "pr-prev", "pr-prev-menu":
            scene(launch: PricingDebugLaunch(
                showsProducts: true, manualPrices: ["BRA": Decimal(string: "149.90") ?? 0],
                previewTerritoryID: "BRA", opensPreviewMenu: id == "pr-prev-menu"
            ))
        case "pr-prev-loading":
            scene(services: DebugPricingServices(sheetDelay: .seconds(3600), launch: PricingDebugLaunch(showsProducts: true)))
        case "pricing-suggest":
            scene(launch: PricingDebugLaunch(countries: PricesByCountryDebugLaunch(popoverTerritory: "BRA")))
        case "pricing-breakdown":
            scene(launch: PricingDebugLaunch(
                appliedSuggestions: ["BRA", "IND", "IDN"], countries: PricesByCountryDebugLaunch(popoverTerritory: "BRA")
            ))
        case "pricing-applied":
            scene(launch: PricingDebugLaunch(follows: true, manualPrices: ["DEU": Decimal(string: "34.99") ?? 0]))
        case "pricing-bulk":
            scene(launch: PricingDebugLaunch(
                filters: PricesByCountryFilters(regions: [.asiaPacific]), selection: ["IND", "IDN", "PHL", "VNM"]
            ))
        default:
            nil
        }
    }

    @MainActor
    private static func stateScene(_ id: String) -> AnyView? {
        switch id {
        case "pricing-nosales":
            scene(services: DebugPricingServices(canReadSales: false))
        case "pricing-skeleton":
            scene(services: DebugPricingServices(sheetDelay: .seconds(3600), delaysRefreshOnly: true, launch: PricingDebugLaunch(refreshes: true)))
        case "pricing-refresh":
            scene(services: DebugPricingServices(sheetDelay: .seconds(2), delaysRefreshOnly: true, launch: PricingDebugLaunch(refreshes: true)))
        case "pricing-nosubs":
            scene(app: AppIDs.quiet, pricingModes: DebugWorkspace.pricingModes.merging([AppIDs.quiet: .showSuggestions]) { $1 })
        case "iap":
            scene(launch: PricingDebugLaunch(productID: DebugPricingCatalog.lumenLifetimeID))
        case "price-br":
            scene(launch: PricingDebugLaunch(analyticsTerritory: "BR"))
        case "pr-newsub-noshot":
            scene(launch: PricingDebugLaunch(showsProducts: true, queuesNewInAppPurchase: true))
        default:
            nil
        }
    }

    @MainActor
    private static func customizeScene(_ id: String) -> AnyView? {
        switch id {
        case "custom":
            scene(launch: PricingDebugLaunch(follows: true, strategy: customStrategy, selection: ["BRA"], showsInspector: true))
        case "custom-tune":
            scene(launch: PricingDebugLaunch(
                follows: true, strategy: customStrategy, selection: ["JPN"], showsInspector: true,
                collapsedSections: [.method, .priceIndex, .fallback]
            ))
        case "custom-csv":
            scene(launch: PricingDebugLaunch(strategy: customIndexStrategy, showsInspector: true, showsImport: true))
        default:
            nil
        }
    }

    @MainActor
    private static func viewScene(_ id: String) -> AnyView? {
        switch id {
        case "pricing-map":
            scene(launch: PricingDebugLaunch(follows: true, display: .map))
        case "pricing-hist":
            scene(launch: PricingDebugLaunch(follows: true, display: .histogram))
        case "schedule":
            scene(launch: PricingDebugLaunch(
                follows: true, strategy: premiumStrategy, schedule: PriceSchedule(startDay: "2026-11-02"), showsSchedule: true,
                today: PricingSampleData.pushDate
            ))
        case "results":
            resultsScene(today: PricingSampleData.date("2026-11-23"))
        case "results-waiting":
            resultsScene(today: PricingSampleData.pushDate)
        case "offers":
            scene(launch: PricingDebugLaunch(productTab: .offers, offerID: "promo"))
        default:
            nil
        }
    }

    /// Create In-App Purchase, Add Introductory Offer… and Review Screenshot…
    /// over the product cards.
    @MainActor
    private static func setupScene(_ id: String) -> AnyView? {
        if let state = ReviewShotsDebugState(sceneID: id) {
            return scene(launch: PricingDebugLaunch(showsProducts: true, reviewShots: state))
        }
        if let sheet = SubscriptionOfferDebugSheet(rawValue: id) {
            return scene(launch: PricingDebugLaunch(
                productID: DebugPricingCatalog.lumenMonthlyID, productTab: .offers, hasSampleOffers: true, offerSheet: sheet
            ))
        }
        if let sheet = InAppPurchaseOfferCodeDebugSheet(rawValue: id) {
            return scene(launch: PricingDebugLaunch(
                productID: DebugPricingCatalog.lumenLifetimeID, productTab: .offers, hasSampleOffers: true, inAppPurchaseOfferSheet: sheet
            ))
        }
        if id == "iap-offers" {
            return scene(launch: PricingDebugLaunch(
                productID: DebugPricingCatalog.lumenLifetimeID, productTab: .offers,
                offerID: ExistingInAppPurchaseOfferCode.offerID(InAppPurchaseOfferCodesSampleData.offerCode.id), hasSampleOffers: true
            ))
        }
        if id == "offers-all" {
            return scene(launch: PricingDebugLaunch(
                productID: DebugPricingCatalog.lumenMonthlyID, productTab: .offers,
                offerID: ExistingOfferCode.offerID(SubscriptionOffersSampleData.offerCode.id), hasSampleOffers: true
            ))
        }
        let sheet: PricingDebugSheet? = switch id {
        case "new-iap": .newInAppPurchase
        case "intro-offer": .introductoryOffer(productID: DebugPricingCatalog.lumenMonthlyID)
        case "review-screenshot": .reviewScreenshot(productID: DebugPricingCatalog.lumenLifetimeID)
        default: nil
        }
        guard let sheet else { return nil }
        return scene(launch: PricingDebugLaunch(showsProducts: true, sheet: sheet))
    }

    /// Lumen Annual's push on Oct 26, 2026 on top of the usual history.
    @MainActor
    private static func resultsScene(today: Date) -> AnyView {
        let records = [DebugPricingResults.annualPush()].compactMap(\.self) + DebugWorkspace.pushRecords
        return scene(launch: PricingDebugLaunch(productTab: .results, today: today), pushRecords: records)
    }

    /// World Bank prices that may go up to 130% of equalized, so some
    /// territories rise.
    static var premiumStrategy: PricingStrategy {
        var strategy = PricingStrategy.recommended
        strategy.method = .priceIndex
        strategy.indexSource = .worldBank
        strategy.discountOnly = false
        strategy.ceiling = Decimal(130) / 100
        return strategy
    }

    /// Big Mac Index with World Bank as fallback, intensity 80%, floor 35%
    /// and Japan excluded.
    private static var customStrategy: PricingStrategy {
        var strategy = PricingStrategy.recommended
        strategy.method = .priceIndex
        strategy.indexSource = .bigMac
        strategy.fallback = [.index(.worldBank), .regionMedian, .equalized]
        strategy.intensity = Decimal(80) / 100
        strategy.floor = Decimal(35) / 100
        strategy.excludedTerritoryIDs = ["JPN"]
        return strategy
    }

    private static var customIndexStrategy: PricingStrategy {
        var strategy = customStrategy
        strategy.indexSource = .custom
        return strategy
    }

    @MainActor
    static func scene(
        app: StoreApp.ID = AppIDs.lumen,
        services pricing: DebugPricingServices? = nil,
        launch: PricingDebugLaunch? = nil,
        pricingModes: [StoreApp.ID: PricingMode] = DebugWorkspace.pricingModes,
        pushRecords: [PushRecord] = DebugWorkspace.pushRecords
    ) -> AnyView {
        var services = WorkspaceServices.debug
        var pricingServices = pricing ?? DebugPricingServices()
        if let launch { pricingServices.launch = launch }
        services.pricing = pricingServices
        return AnyView(DebugMainScene(
            services: services, selectedAppID: app, section: .subscriptionPricing, pushRecords: pushRecords, pricingModes: pricingModes
        ))
    }
}
#endif
