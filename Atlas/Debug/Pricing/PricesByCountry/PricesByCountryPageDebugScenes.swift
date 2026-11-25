//
//  PricesByCountryPageDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Prices by Country's states on Lumen Plus Annual's page, in the whole
/// window (board 73). `PricingProductPageDebugScenes` asks here for ids it
/// doesn't know.
///
/// - `pr-prod-why`: Brazil's popover on its suggested price, with why.
/// - `pr-prod-adjusted`: Brazil's suggestion accepted one point up:
///   Adjusted suggestion.
/// - `pr-prod-map`, `pr-prod-map-sug`: the map, Now or Suggested.
/// - `pr-prod-hist`: the histogram.
/// - `pr-prod-strat`: Apply Recommended Prices chosen: every suggestion
///   waits in Review & Push.
/// - `pr-prod-keep`: Keep Prices: no banner, the strategy in the toolbar.
/// - `pr-prod-insp`: Customize Suggestions… open.
/// - `pr-prod-acc`, `pr-prod-acc-off`: Accept All N… with increases, existing
///   subscribers keeping their price or not (the amber note).
/// - `pr-prod-start`: price changes starting on a date, in the footer.
/// - `pr-prod-results`, `pr-prod-results-none`: the Results tab four weeks
///   after a push, or with nothing to compare.
/// - `pr-prod-filters`: Europe and Increases Only, the Filters popover open.
/// - `pr-prod-cols`: every column the Columns menu adds.
/// - `pr-prod-fallback`: Fallback Only, with the Source column.
/// - `pr-prod-up`: a strategy that raises some prices, the biggest rise first.
enum PricesByCountryPageDebugScenes {
    static let ids = [
        "pr-prod-why", "pr-prod-adjusted", "pr-prod-map", "pr-prod-map-sug", "pr-prod-hist", "pr-prod-strat", "pr-prod-keep",
        "pr-prod-insp", "pr-prod-acc", "pr-prod-acc-off", "pr-prod-start", "pr-prod-results", "pr-prod-results-none",
        "pr-prod-filters", "pr-prod-cols", "pr-prod-fallback", "pr-prod-up",
    ]

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        countriesScene(id) ?? pageScene(id)
    }

    @MainActor
    private static func countriesScene(_ id: String) -> AnyView? {
        switch id {
        case "pr-prod-why":
            page(PricingDebugLaunch(countries: PricesByCountryDebugLaunch(popoverTerritory: "BRA")))
        case "pr-prod-adjusted":
            page(PricingDebugLaunch(countries: PricesByCountryDebugLaunch(adjustedTerritory: "BRA")))
        case "pr-prod-map", "pr-prod-map-sug":
            page(PricingDebugLaunch(display: .map, countries: PricesByCountryDebugLaunch(mapShowsSuggested: id == "pr-prod-map-sug")))
        case "pr-prod-hist":
            page(PricingDebugLaunch(display: .histogram))
        case "pr-prod-filters":
            page(PricingDebugLaunch(
                filters: PricesByCountryFilters(regions: [.europe], increasesOnly: true),
                strategy: PricingDebugScenes.premiumStrategy,
                countries: PricesByCountryDebugLaunch(opensFilters: true)
            ))
        case "pr-prod-cols":
            page(PricingDebugLaunch(countries: PricesByCountryDebugLaunch(shownColumns: PricesByCountryColumn.optional)))
        case "pr-prod-fallback":
            page(PricingDebugLaunch(
                filters: PricesByCountryFilters(fallbackOnly: true),
                countries: PricesByCountryDebugLaunch(shownColumns: [.provenance, .reason])
            ))
        case "pr-prod-up":
            page(PricingDebugLaunch(strategy: PricingDebugScenes.premiumStrategy, countries: PricesByCountryDebugLaunch(sortsByRise: true)))
        default:
            nil
        }
    }

    @MainActor
    private static func pageScene(_ id: String) -> AnyView? {
        switch id {
        case "pr-prod-strat":
            page(PricingDebugLaunch(follows: true))
        case "pr-prod-keep":
            PricingDebugScenes.scene(
                launch: launch(PricingDebugLaunch()),
                pricingModes: DebugWorkspace.pricingModes.merging([DebugFixtures.AppID.lumen: .keepPrices]) { $1 }
            )
        case "pr-prod-insp":
            page(PricingDebugLaunch(showsInspector: true))
        case "pr-prod-acc", "pr-prod-acc-off":
            page(PricingDebugLaunch(
                strategy: PricingDebugScenes.premiumStrategy,
                schedule: PriceSchedule(preservesCurrentPrice: id == "pr-prod-acc"),
                countries: PricesByCountryDebugLaunch(opensAcceptAll: true)
            ))
        case "pr-prod-start":
            page(PricingDebugLaunch(
                manualPrices: ["BRA": Decimal(string: "149.90") ?? 0],
                schedule: PriceSchedule(startDay: "2026-12-01"),
                today: PricingSampleData.pushDate
            ))
        case "pr-prod-results":
            PricingDebugScenes.scene(
                launch: launch(PricingDebugLaunch(productTab: .results, today: PricingSampleData.date("2026-11-23"))),
                pushRecords: [DebugPricingResults.annualPush()].compactMap(\.self) + DebugWorkspace.pushRecords
            )
        case "pr-prod-results-none":
            PricingDebugScenes.scene(launch: launch(PricingDebugLaunch(productTab: .results)), pushRecords: [])
        default:
            nil
        }
    }

    /// Lumen Plus Annual's page with `launch`.
    @MainActor
    private static func page(_ launch: PricingDebugLaunch) -> AnyView {
        PricingDebugScenes.scene(launch: self.launch(launch))
    }

    private static func launch(_ launch: PricingDebugLaunch) -> PricingDebugLaunch {
        var launch = launch
        launch.productPage = PricingProductRoute(productID: annual, tab: launch.productTab ?? .pricesByCountry)
        return launch
    }
}
#endif
