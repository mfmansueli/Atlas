//
//  PricingProductPageDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The product page's DEBUG scenes (board 73), on Lumen Plus Annual over
/// Lumen Journal's product cards. `DebugSceneView` asks here for ids it
/// doesn't know; Prices by Country's own states are in
/// `PricesByCountryPageDebugScenes`.
///
/// - `pr-prod`: the page on Prices by Country.
/// - `pr-prod-sel-chat`: Brazil selected, its bar above the chat's pill.
/// - `pr-open`: opened from Show Countries, on the Suggested filter.
/// - `pr-prod-offers`: the Offers tab (its introductory and promotional offers).
/// - `pr-prod-rs`: the Review Screenshot tab, missing, with a capture of the paywall.
/// - `pr-prod-details`: the Details tab.
/// - `pr-prod-life-offers`: Lumen Lifetime's Offers tab: no subscription offers, its offer codes.
/// - `pr-prod-loading`: Lumen Plus Monthly's Offers tab while its prices are
///   read (they never arrive).
/// - `pr-prod-details-error`: the Details tab after App Store Connect failed.
enum PricingProductPageDebugScenes {
    static let ids = [
        "pr-prod", "pr-prod-sel-chat", "pr-open", "pr-prod-offers", "pr-prod-rs", "pr-prod-details", "pr-prod-life-offers", "pr-prod-loading",
        "pr-prod-details-error",
    ] + PricesByCountryPageDebugScenes.ids

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod":
            scene(PricingProductRoute(productID: annual))
        case "pr-prod-sel-chat":
            scene(PricingProductRoute(productID: annual, focusedTerritory: "BRA"))
        case "pr-open":
            scene(PricingProductRoute(productID: annual, filter: .suggested))
        case "pr-prod-offers":
            scene(PricingProductRoute(productID: annual, tab: .offers))
        case "pr-prod-rs":
            scene(PricingProductRoute(productID: annual, tab: .reviewScreenshot), reviewShots: .match)
        case "pr-prod-details":
            scene(PricingProductRoute(productID: annual, tab: .details))
        case "pr-prod-life-offers":
            scene(PricingProductRoute(productID: DebugPricingCatalog.lumenLifetimeID, tab: .offers), hasSampleOffers: true)
        case "pr-prod-loading":
            scene(
                PricingProductRoute(productID: DebugPricingCatalog.lumenMonthlyID, tab: .offers),
                services: DebugPricingServices(sheetDelay: .seconds(3600), delaysRefreshOnly: true)
            )
        case "pr-prod-details-error":
            scene(PricingProductRoute(productID: annual, tab: .details), failsFacts: true)
        default:
            PricesByCountryPageDebugScenes.view(for: id)
        }
    }

    @MainActor
    private static func scene(
        _ route: PricingProductRoute,
        services: DebugPricingServices = DebugPricingServices(),
        reviewShots: ReviewShotsDebugState? = nil,
        hasSampleOffers: Bool = false,
        failsFacts: Bool = false
    ) -> AnyView {
        var workspace = WorkspaceServices.debug
        var pricing = services
        var launch = pricing.launch ?? PricingDebugLaunch()
        launch.showsProducts = true
        launch.productPage = route
        launch.reviewShots = reviewShots
        launch.hasSampleOffers = hasSampleOffers
        launch.failsProductFacts = failsFacts
        pricing.launch = launch
        workspace.pricing = pricing
        return AnyView(DebugMainScene(
            services: workspace, selectedAppID: DebugFixtures.AppID.lumen, section: .subscriptionPricing,
            pushRecords: DebugWorkspace.pushRecords, pricingModes: DebugWorkspace.pricingModes
        ))
    }
}
#endif
