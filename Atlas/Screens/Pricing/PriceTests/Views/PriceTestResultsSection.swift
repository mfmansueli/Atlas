//
//  PriceTestResultsSection.swift
//  Atlas
//

import SwiftUI

/// Results' price tests (board 76): the header with Test a Price…, the
/// assistant's suggested tests, then each test of the product not yet Done.
struct PriceTestResultsSection: View {
    let viewModel: PricingViewModel
    let productID: PricingProduct.ID
    let isFree: Bool
    let onTest: () -> Void

    var body: some View {
        let tests = viewModel.priceTests
        let today = viewModel.today()
        VStack(alignment: .leading, spacing: Spacing.medium) {
            PriceTestResultsHeader(isFree: isFree, onTest: onTest)
            ForEach(tests.suggestions(productID: productID)) { suggestion in
                PriceTestSuggestionCard(
                    suggestion: suggestion,
                    onDismiss: { tests.dismissSuggestion(suggestion.id) },
                    onSetUp: { viewModel.openPriceTest(from: suggestion) }
                )
            }
            ForEach(tests.shownTests(productID: productID, on: today)) { test in
                card(test, phase: test.phase(on: today))
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.medium)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.results.priceTests")
    }

    private func card(_ test: PriceTest, phase: PriceTestPhase) -> some View {
        let tests = viewModel.priceTests
        return PriceTestCard(
            test: test,
            phase: phase,
            isEndQueued: tests.isEndQueued(test),
            isDetailsOpen: tests.expandedTestIDs.contains(test.id),
            onRemove: { viewModel.removePriceTest(test.id) },
            onReview: { viewModel.onOpenReview() },
            onShowCountries: { viewModel.showPriceTestCountries(test) },
            onEndEarly: { viewModel.askToEndPriceTest(test) },
            onToggleDetails: { tests.toggleDetails(test.id) },
            onDone: { tests.markDone(test.id) },
            onKeep: { tests.keepingTestID = test.id },
            onTestAgain: { viewModel.testAgain(test) }
        )
    }
}
