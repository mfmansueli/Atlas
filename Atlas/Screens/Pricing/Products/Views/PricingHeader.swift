//
//  PricingHeader.swift
//  Atlas
//

import SwiftUI

/// The top of Pricing's Prices page: what Pricing changes, Prices |
/// Retention with the Prices count, Add Subscription…, and More (Add In-App
/// Purchase…, the pricing mode, Customize…, every price of a product, and
/// Restore Dismissed). The prototype's header holds only the segments and
/// Add Subscription…, so the rest waits in More.
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
            Button {
                viewModel.isNewSubscriptionSheetPresented = true
            } label: {
                Label("Add Subscription…", systemImage: "plus")
            }
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("pricing.addSubscription")
            moreMenu
        }
    }

    /// "What Lumen’s subscriptions and purchases cost in 175 countries and
    /// regions."
    private var subtitle: String {
        guard let count = viewModel.territoryCount else {
            return String(localized: "What \(viewModel.app.name)’s subscriptions and purchases cost in each country and region.")
        }
        return String(localized: "What \(viewModel.app.name)’s subscriptions and purchases cost in \(count) countries and regions.")
    }

    private var moreMenu: some View {
        Menu {
            Button("Add In-App Purchase…") { viewModel.setup.isNewInAppPurchaseSheetPresented = true }
                .accessibilityIdentifier("pricing.addInAppPurchase")
            Section(String(localized: "Pricing Mode for \(viewModel.app.name)")) {
                ForEach(PricingMode.allCases) { mode in
                    Toggle(isOn: Binding(
                        get: { viewModel.mode == mode },
                        set: { _ in Task { await viewModel.setMode(mode) } }
                    )) {
                        Text(mode.title)
                        Text(PricingModeMenu.description(of: mode))
                    }
                }
            }
            Divider()
            if let product = viewModel.selectedProduct ?? viewModel.catalog?.defaultProduct {
                Button("Every Price of \(product.name)…") {
                    Task { await viewModel.openDetails(productID: product.id) }
                }
            }
            if viewModel.mode != .keepPrices {
                Button("Customize Pricing Strategy…") { viewModel.isInspectorPresented = true }
            }
            if viewModel.hasDismissedPriceSuggestions {
                Divider()
                Button("Restore Dismissed Suggestions") { viewModel.restoreDismissedPriceSuggestions() }
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
