//
//  PriceTestDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 76's price test scenes on Lumen Plus Annual: where Test a Price…
/// starts, the sheet and its refusals, the confirmation, Review & Push,
/// the running test in Results, Prices by Country and the product list,
/// ending it, the verdicts, Keep, the assistant's card and Free.
enum PriceTestDebugScenes {
    static let ids = [
        "pt-strat", "pt-res", "pt-res-empty", "pt-setup", "pt-setup-pp", "pt-setup-up", "pt-setup-few", "pt-setup-ctl", "pt-confirm",
        "pt-rp", "pt-run", "pt-run-prices", "pt-run-list", "pt-pop", "pt-conflict", "pt-acc", "pt-stop", "pt-ready", "pt-ready-det",
        "pt-keep", "pt-kept", "pt-worse", "pt-few", "pt-cc", "pt-res-free",
    ]

    private static let annual = DebugPricingCatalog.lumenAnnualID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pt-strat": scene(.none, tab: .pricesByCountry)
        case "pt-res": scene(.none, tab: .results)
        case "pt-res-empty": scene(.none, tab: .results, pushRecords: [])
        case "pt-setup": scene(.setup(.europe, .percent(-20)), tab: .results)
        case "pt-setup-pp": scene(.setup(.asiaPacific, .suggested), tab: .results)
        case "pt-setup-up": scene(.setup(.europe, .percent(10)), tab: .results)
        case "pt-setup-few": scene(.setup(.africaMiddleEast, .percent(-20)), tab: .results)
        case "pt-setup-ctl": scene(.setup(.europe, .percent(-20), control: .none), tab: .results)
        case "pt-confirm": scene(.setup(.europe, .percent(-20), confirming: true), tab: .results)
        case "pt-rp": scene(.queued, tab: .results)
        case "pt-run": scene(.running, tab: .results)
        case "pt-run-prices": scene(.running, tab: .pricesByCountry)
        case "pt-run-list": scene(.running, tab: nil)
        case "pt-pop": scene(.running, tab: .pricesByCountry, countries: PricesByCountryDebugLaunch(popoverTerritory: "DEU"))
        case "pt-conflict": scene(.conflict, tab: .pricesByCountry)
        case "pt-acc": scene(.running, tab: .pricesByCountry, countries: PricesByCountryDebugLaunch(opensAcceptAll: true))
        case "pt-stop": scene(.stopping, tab: .results)
        case "pt-ready": scene(.ready(.better), tab: .results)
        case "pt-ready-det": scene(.ready(.better, details: true), tab: .results)
        case "pt-keep": scene(.keeping, tab: .results)
        case "pt-kept": scene(.kept, tab: .results)
        case "pt-worse": scene(.ready(.worse), tab: .results)
        case "pt-few": scene(.ready(.tooLittleData), tab: .results)
        case "pt-cc": scene(.suggested, tab: .results)
        case "pt-res-free": scene(.none, tab: .results, isFree: true)
        default: nil
        }
    }

    /// Lumen's Pricing on the product's page (`tab`), or on the products
    /// when `tab` is nil.
    @MainActor
    private static func scene(
        _ state: PriceTestDebugState,
        tab: PricingProductTab?,
        countries: PricesByCountryDebugLaunch? = nil,
        pushRecords: [PushRecord] = DebugWorkspace.pushRecords,
        isFree: Bool = false
    ) -> AnyView {
        var workspace = WorkspaceServices.debug
        var pricing = DebugPricingServices()
        var launch = PricingDebugLaunch()
        launch.today = DebugPriceTests.today
        launch.showsProducts = true
        launch.productPage = tab.map { PricingProductRoute(productID: annual, tab: $0) }
        launch.countries = countries
        launch.priceTests = PriceTestDebugLaunch(state: state)
        pricing.launch = launch
        workspace.pricing = pricing
        return AnyView(DebugMainScene(
            services: workspace, selectedAppID: DebugFixtures.AppID.lumen, section: .subscriptionPricing,
            pushRecords: pushRecords, pricingModes: DebugWorkspace.pricingModes, isFree: isFree
        ))
    }
}
#endif
