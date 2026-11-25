//
//  PricingDecisionsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The states board 76's small Pricing decisions changed, on Lumen Plus
/// Annual (`-AtlasDebugScene <id>`):
///
/// - `pr-prod-matched-grey`: no suggestion to make: the summary line in the
///   secondary grey, not blue (nothing waits for you).
/// - `pr-prod-borrowed`: Portugal uses Europe's sales: "Uses Europe’s sales"
///   in the Source and Reason columns, "Too few sales here, so Atlas uses
///   Europe’s." in their help, and the banner's one line "Based on your
///   sales in N countries · M use their region’s".
/// - `pr-prod-checking-line`: "Checking Apple’s prices…" as a plain line in
///   the banner's place, no grey surface (the points never arrive).
/// - `pr-prod-card-grid-error`: the product cards after Apple's price
///   points failed (a 500): the amber error template with Try Again.
/// - `pr-prod-results-toofew-starts`, `pr-prod-results-toofew-views`:
///   Results with Portugal too few to tell, and the line under its pill:
///   "12 starts · needs 30", or "64 page views · needs 100".
/// - `settings-price-data`, `settings-price-data-failed`: Settings → Price
///   data with the bundled editions and the exchange rates' source and day,
///   Update Now, and an update that failed.
enum PricingDecisionsDebugScenes {
    static let ids = [
        "pr-prod-matched-grey", "pr-prod-borrowed", "pr-prod-checking-line", "pr-prod-card-grid-error",
        "pr-prod-results-toofew-starts", "pr-prod-results-toofew-views", "settings-price-data", "settings-price-data-failed",
    ]

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-matched-grey":
            AnyView(PricingConfidenceDebugHost(scenario: .matched))
        case "pr-prod-borrowed":
            AnyView(PricingConfidenceDebugHost(scenario: .thin, focusedTerritory: "PRT", shownColumns: [.provenance]))
        case "pr-prod-checking-line":
            gridScene(products: false, fails: false)
        case "pr-prod-card-grid-error":
            gridScene(products: true, fails: true)
        case "pr-prod-results-toofew-starts":
            resultsScene(portugal: portugalShortOfStarts)
        case "pr-prod-results-toofew-views":
            resultsScene(portugal: portugalShortOfPageViews)
        case "settings-price-data":
            priceDataScene(failure: nil)
        case "settings-price-data-failed":
            priceDataScene(failure: AppleErrorCopy(
                String(localized: "Exchange rates didn’t update.", comment: "kind:error"), error: URLError(.notConnectedToInternet)
            ))
        default:
            nil
        }
    }

    // MARK: - Apple's price points

    /// Apple's price points never arriving on the product's page, or
    /// failing on the product cards.
    @MainActor
    private static func gridScene(products: Bool, fails: Bool) -> AnyView {
        var services = DebugPricingServices(simulatesGrid: true)
        if fails {
            services.laddersError = .server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side.")
        } else {
            services.laddersDelay = .seconds(3600)
        }
        var launch = PricingDebugLaunch(showsProducts: products)
        if !products { launch.productPage = PricingProductRoute(productID: annual, tab: .pricesByCountry) }
        return PricingDebugScenes.scene(services: services, launch: launch)
    }

    // MARK: - Results

    /// 12 and 14 starts either side: short of 30 starts.
    static let portugalShortOfStarts = SalesComparison(
        before: SalesWindow(pageViews: 380, starts: 12, proceeds: 336), after: SalesWindow(pageViews: 391, starts: 14, proceeds: 300)
    )

    /// 31 and 33 starts but 64 and 70 page views: short of 100 page views.
    static let portugalShortOfPageViews = SalesComparison(
        before: SalesWindow(pageViews: 64, starts: 31, proceeds: 868), after: SalesWindow(pageViews: 70, starts: 33, proceeds: 706)
    )

    /// The Results tab for the prices read on Oct 20, Portugal's windows
    /// replaced by `portugal`.
    @MainActor
    private static func resultsScene(portugal: SalesComparison) -> AnyView {
        let records = DebugPricingSales.readChanges(productID: annual).map { record in
            guard record.territoryID == "PRT" else { return record }
            var record = record
            record.before = signal(portugal.before)
            record.after = signal(portugal.after)
            return record
        }
        var launch = PricingDebugLaunch(productTab: .results, today: PricingSampleData.date("2026-11-23"))
        launch.productPage = PricingProductRoute(productID: annual, tab: .results)
        return PricingDebugScenes.scene(services: DebugPricingServices(priceChanges: records), launch: launch, pushRecords: [])
    }

    private static func signal(_ window: SalesWindow) -> SalesSignal {
        SalesSignal(pageViews: window.pageViews, starts: window.starts, proceeds: window.proceeds)
    }

    // MARK: - Settings

    /// Settings → Price data alone, with the bundled exchange rates (never
    /// fetched: Update Now keeps them).
    @MainActor
    private static func priceDataScene(failure: AppleErrorCopy?) -> AnyView {
        let store = ExchangeRateStore(bundled: (try? ExchangeRates.bundled()) ?? .approximate, cache: InMemoryExchangeRateCache(), fetcher: nil)
        return AnyView(
            Form {
                PriceDataSettingsSection(store: store, failure: failure)
            }
            .formStyle(.grouped)
            .frame(width: 640, height: 320)
        )
    }
}
#endif
