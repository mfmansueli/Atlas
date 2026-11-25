//
//  PricingSalesDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Lumen Plus Annual's page with each sales state (`DebugPricingSales`),
/// and Results for a change read from App Store Connect.
///
/// - `pr-prod-sales`: sales read: Europe with traffic, Portugal thin,
///   Brazil with a past change and both 28-day windows kept.
/// - `pr-prod-sales-none`: no sales yet (Alba's case): page views only.
/// - `pr-prod-sales-role`: a key whose role can't read Sales and Trends.
/// - `pr-prod-sales-off`: sales data turned off in Settings → Pricing.
/// - `pr-prod-sales-unread`: Analytics never set up, nothing downloaded.
/// - `pr-prod-results-read`: Results for prices changed in App Store
///   Connect on Oct 20, 2026: Better, Worse, About the same and Too few to
///   tell, without Restore (nothing was pushed).
enum PricingSalesDebugScenes {
    static let ids = [
        "pr-prod-sales", "pr-prod-sales-none", "pr-prod-sales-role", "pr-prod-sales-off", "pr-prod-sales-unread", "pr-prod-results-read",
    ]

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-sales": salesScene(.available)
        case "pr-prod-sales-none": salesScene(.noSalesYet)
        case "pr-prod-sales-role": salesScene(.roleCannotRead)
        case "pr-prod-sales-off": salesScene(.turnedOff)
        case "pr-prod-sales-unread": salesScene(.notRead)
        case "pr-prod-results-read":
            PricingDebugScenes.scene(
                services: DebugPricingServices(priceChanges: DebugPricingSales.readChanges(productID: annual)),
                launch: page(PricingDebugLaunch(productTab: .results, today: PricingSampleData.date("2026-11-23"))),
                pushRecords: []
            )
        default: nil
        }
    }

    @MainActor
    private static func salesScene(_ availability: PricingSalesData.Availability) -> AnyView {
        let product = DebugPricingCatalog.catalog(for: DebugPricingSales.appID).product(id: annual)
        let sales = product.map { DebugPricingSales.salesData(for: $0, availability: availability) }
        return PricingDebugScenes.scene(
            services: DebugPricingServices(canReadSales: sales?.canRead ?? false, sales: sales),
            launch: page(PricingDebugLaunch())
        )
    }

    private static func page(_ launch: PricingDebugLaunch) -> PricingDebugLaunch {
        var launch = launch
        launch.productPage = PricingProductRoute(productID: annual, tab: launch.productTab ?? .pricesByCountry)
        return launch
    }
}
#endif
