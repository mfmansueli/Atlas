//
//  PricingResultsView.swift
//  Atlas
//

import SwiftUI

/// The Results tab: nothing to compare yet, too early to tell, results
/// that need sales Atlas can't read, or the before-and-after report.
struct PricingResultsView: View {
    let viewModel: PricingViewModel

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        // A stack rather than a Group, so the tab's identifier stays on the
        // tab instead of replacing each state's own.
        VStack(spacing: 0) {
            if let productID {
                PriceTestResultsSection(viewModel: viewModel, productID: productID, isFree: pro.isFree) {
                    pro.require(.priceTest) { viewModel.openPriceTest(productID: productID) }
                }
            }
            if let model = viewModel.results {
                content(model)
            } else {
                loading
                    .task { await viewModel.loadResults() }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .modifier(PriceTestSheetsModifier(viewModel: viewModel))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.results")
    }

    /// The product whose Results these are.
    private var productID: PricingProduct.ID? {
        viewModel.productRoute?.productID ?? viewModel.selectedProduct?.id
    }

    @ViewBuilder
    private func content(_ model: PriceResultsModel) -> some View {
        switch model.state {
        case .loading:
            loading
        case .noChanges:
            // Board 74: nothing pushed yet to compare.
            EmptyStateView(
                String(localized: "No price changes to compare yet", comment: "kind:empty"),
                systemImage: "chart.bar",
                text: String(localized: "Push a price change, or try one first with Test a Price…: one region pays it for 28 days.", comment: "kind:empty")
            )
            .accessibilityIdentifier("pricing.results.none")
        case let .tooEarly(changedOn, day, arrivesOn):
            ResultsWaitingView(changedOn: changedOn, day: day, arrivesOn: arrivesOn)
        case let .salesUnavailable(changedOn):
            ContentUnavailableView {
                Label(String(localized: "Results need sales data", comment: "kind:empty"), systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text(String(
                    localized: """
                    Prices changed on \(PricingText.date(changedOn)). To compare, set up Sales and Trends in Analytics and keep sales \
                    data on in Settings → Pricing.
                    """,
                    comment: "kind:empty"
                ))
            }
            .accessibilityIdentifier("pricing.results.noSales")
        case let .ready(changedOn):
            ResultsReportView(model: model, changedOn: changedOn)
        case let .failed(message):
            ContentUnavailableView {
                Label("Results couldn’t load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { viewModel.resultsDidChange() }
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("pricing.results.tryAgain")
            }
        }
    }

    private var loading: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
