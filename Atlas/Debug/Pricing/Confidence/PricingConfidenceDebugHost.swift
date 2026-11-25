//
//  PricingConfidenceDebugHost.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Lumen Plus Annual's Prices by Country in a plain frame with one of
/// HowSure's sample sales, the Reason column shown, and optionally a
/// country selected or its popover open.
struct PricingConfidenceDebugHost: View {
    let scenario: DebugPricingConfidenceSales.Scenario
    var focusedTerritory: String?
    var popoverTerritory: String?
    /// Columns shown besides Reason, e.g. Source (`pr-prod-borrowed`).
    var shownColumns: [PricesByCountryColumn] = []

    @State private var viewModel: PricingViewModel
    @State private var shownFilter: PricesByCountryFilter = .all
    @State private var shownFocus: String?
    @State private var isReady = false

    private static let productID = DebugPricingCatalog.lumenAnnualID

    init(
        scenario: DebugPricingConfidenceSales.Scenario,
        focusedTerritory: String? = nil,
        popoverTerritory: String? = nil,
        shownColumns: [PricesByCountryColumn] = []
    ) {
        self.scenario = scenario
        self.focusedTerritory = focusedTerritory
        self.popoverTerritory = popoverTerritory
        self.shownColumns = shownColumns
        _viewModel = State(initialValue: PricingViewModel(
            app: DebugFixtures.lumen,
            services: DebugConfidencePricingServices(scenario: scenario),
            queue: ChangeQueue(),
            modes: PricingModeStore(defaults: nil, modes: [DebugFixtures.AppID.lumen: .showSuggestions]),
            commission: .smallBusiness
        ))
    }

    var body: some View {
        Group {
            if isReady {
                PricesByCountryView(viewModel: viewModel, productID: Self.productID, filter: $shownFilter, focusedTerritory: $shownFocus)
            } else {
                PricesByCountrySkeleton()
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 1000, height: 640)
        .background(Palette.content)
        .task {
            await viewModel.load()
            await viewModel.productsTask?.value
            viewModel.pricesByCountry.show(productID: Self.productID)
            viewModel.pricesByCountry.setShown(.reason, true)
            for column in shownColumns { viewModel.pricesByCountry.setShown(column, true) }
            shownFocus = focusedTerritory
            isReady = true
            try? await Task.sleep(for: .milliseconds(600))
            if let territoryID = popoverTerritory, let row = viewModel.countryRow(productID: Self.productID, territoryID: territoryID) {
                viewModel.pricesByCountry.popover = .opening(row)
            }
        }
    }
}
#endif
