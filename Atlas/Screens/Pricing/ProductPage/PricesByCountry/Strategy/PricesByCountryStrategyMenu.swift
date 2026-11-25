//
//  PricesByCountryStrategyMenu.swift
//  Atlas
//

import SwiftUI

/// The banner's strategy pop-up (board 73, `pr-prod-strat`), app-wide:
/// Show Suggestions · Apply Recommended Prices · Keep Prices, then
/// Customize Suggestions…, which opens the strategy inspector.
struct PricesByCountryStrategyMenu: View {
    let viewModel: PricingViewModel

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        Menu {
            Section(String(localized: "Prices for \(viewModel.app.name)", comment: "kind:field-label")) {
                ForEach(PricingMode.strategyOrder) { mode in
                    Toggle(isOn: Binding(
                        get: { viewModel.mode == mode },
                        set: { _ in Task { await viewModel.setMode(mode) } }
                    )) {
                        Text(mode.strategyTitle)
                        Text(mode.strategyDetail)
                    }
                    .accessibilityIdentifier("countries.strategy.\(mode.rawValue)")
                }
            }
            Divider()
            Button(String(localized: "Customize Suggestions…", comment: "kind:menu-item")) {
                viewModel.isInspectorPresented = true
            }
            .disabled(viewModel.mode == .keepPrices)
            .accessibilityIdentifier("countries.strategy.customize")
            if let product = testedProduct {
                // Board 76: the product's own choice, under the app-wide ones.
                Section(String(localized: "For \(product.name)", comment: "kind:field-label")) {
                    Button {
                        pro.require(.priceTest) { viewModel.openPriceTest(productID: product.id) }
                    } label: {
                        Text("Test a Price…", comment: "kind:menu-item")
                        Text("One region, 28 days, to make suggestions sure", comment: "kind:menu-item")
                    }
                    .accessibilityIdentifier("countries.strategy.testPrice")
                }
            }
        } label: {
            Text(viewModel.mode.strategyTitle)
        }
        .menuStyle(.button)
        .fixedSize()
        .help(Text("How Atlas suggests prices for this app", comment: "kind:tooltip"))
        .accessibilityLabel(Text("Strategy", comment: "kind:accessibility-label"))
        .accessibilityValue(Text(viewModel.mode.strategyTitle))
        .accessibilityIdentifier("countries.strategy")
    }

    /// The subscription whose Prices by Country is open.
    private var testedProduct: PricingProduct? {
        guard let id = viewModel.pricesByCountry.productID, let product = viewModel.countriesProduct(productID: id),
              !product.isInAppPurchase else { return nil }
        return product
    }
}
