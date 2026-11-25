//
//  PricingHeader.swift
//  Atlas
//

import SwiftUI

/// The top of Pricing's Prices page: what Pricing changes, Prices |
/// Retention with the Prices count, and More (Add In-App Purchase…, the
/// pricing mode, Customize…, every price of a product, and Restore
/// Dismissed). The prototype's header holds only the segments, so the rest
/// waits in More; Add Subscription… is the toolbar's page action (board 80).
struct PricingHeader: View {
    @Bindable var viewModel: PricingViewModel

    var body: some View {
        SectionHeader(
            subtitle: subtitle
        ) {
            BadgedSegments(
                label: String(localized: "Pricing"),
                options: [
                    (value: PricingPage.prices, title: PricingPage.prices.title, count: viewModel.openPriceSuggestionCount),
                    (value: PricingPage.retention, title: PricingPage.retention.title, count: 0),
                ],
                selection: $viewModel.page
            )
            .controlSize(.small)
            .accessibilityIdentifier("pricing.page")
            moreMenu
        }
    }

    /// "What Lumen’s subscriptions and purchases cost in 175 countries and
    /// regions."
    private var subtitle: String {
        guard let count = viewModel.territoryCount else {
            return String(localized: "What \(viewModel.app.name) costs, in each country and region.")
        }
        return String(localized: "What \(viewModel.app.name) costs, in \(count) countries and regions.")
    }

    private var moreMenu: some View {
        Menu {
            Button("Add In-App Purchase…", systemImage: "plus") { viewModel.setup.isNewInAppPurchaseSheetPresented = true }
                .accessibilityIdentifier("pricing.addInAppPurchase")
            Section(String(localized: "Pricing Mode for \(viewModel.app.name)")) {
                ForEach(PricingMode.strategyOrder) { mode in
                    Toggle(isOn: Binding(
                        get: { viewModel.mode == mode },
                        set: { _ in Task { await viewModel.setMode(mode) } }
                    )) {
                        Text(mode.strategyTitle)
                        Text(mode.strategyDetail)
                    }
                }
            }
            Divider()
            if viewModel.mode != .keepPrices {
                Button(String(localized: "Customize Suggestions…", comment: "kind:menu-item"), systemImage: "slider.horizontal.3") {
                    viewModel.isInspectorPresented = true
                }
            }
            if viewModel.hasDismissedPriceSuggestions {
                Divider()
                Button("Restore Dismissed Suggestions", systemImage: "arrow.uturn.backward") { viewModel.restoreDismissedPriceSuggestions() }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .accessibilityIdentifier("pricing.more")
    }
}
