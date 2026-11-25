//
//  PricingIndexDataDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Lumen Plus Annual's page priced by the real bundled index
/// (`PriceIndexSnapshot.json`) and exchange rates
/// (`ExchangeRatesSnapshot.json`) instead of the prototype's sample, so the
/// real editions, years and Fallback pills can be seen:
///
/// - `pr-prod-index`: Prices by Country with the Source and Reason
///   columns: "World Bank 2025", Bulgaria's "World Bank 2024" with Fallback.
/// - `pr-prod-index-fallback`: Fallback Only, with the Source column.
/// - `pr-prod-index-why`: Brazil's popover: "World Bank 2025 · factor 0.46".
/// - `pr-prod-index-insp`: Customize Suggestions… open: real editions,
///   fallback counts and "Exchange rates of … · Rates by ExchangeRate-API".
/// - `pr-prod-index-sample`: the inspector on the sample snapshot:
///   "approximate" and "Sample exchange rates, not live quotes".
enum PricingIndexDataDebugScenes {
    static let ids = ["pr-prod-index", "pr-prod-index-fallback", "pr-prod-index-why", "pr-prod-index-insp", "pr-prod-index-sample"]

    /// Scenes whose exchange rates are the bundled ones, read by
    /// `ExchangeRateStore` at launch.
    static func usesBundledData(_ id: String) -> Bool {
        ids.contains(id) && id != "pr-prod-index-sample"
    }

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-index":
            scene(PricingDebugLaunch(countries: PricesByCountryDebugLaunch(shownColumns: [.provenance, .reason])))
        case "pr-prod-index-fallback":
            scene(PricingDebugLaunch(
                filters: PricesByCountryFilters(fallbackOnly: true),
                countries: PricesByCountryDebugLaunch(shownColumns: [.provenance, .reason])
            ))
        case "pr-prod-index-why":
            scene(PricingDebugLaunch(countries: PricesByCountryDebugLaunch(popoverTerritory: "BRA")))
        case "pr-prod-index-insp":
            scene(PricingDebugLaunch(showsInspector: true))
        case "pr-prod-index-sample":
            scene(PricingDebugLaunch(showsInspector: true), snapshot: nil)
        default:
            nil
        }
    }

    /// Lumen Plus Annual's page with `launch`, priced by `snapshot`.
    @MainActor
    private static func scene(_ launch: PricingDebugLaunch, snapshot: PriceIndexSnapshot? = try? PriceIndexSnapshot.bundled()) -> AnyView {
        var launch = launch
        launch.productPage = PricingProductRoute(productID: annual, tab: .pricesByCountry)
        var services = DebugPricingServices()
        services.snapshot = snapshot
        return PricingDebugScenes.scene(services: services, launch: launch)
    }
}
#endif
