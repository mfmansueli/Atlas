//
//  PriceTestSheetsModifier.swift
//  Atlas
//

import SwiftUI

/// Presents the price test sheets wherever they open from: Test a Price,
/// End Test (early, or for a new price) and Keep Test Prices.
struct PriceTestSheetsModifier: ViewModifier {
    let viewModel: PricingViewModel

    func body(content: Content) -> some View {
        let tests = viewModel.priceTests
        content
            .sheet(isPresented: Binding { tests.setup != nil } set: { if !$0 { tests.setup = nil } }) {
                PriceTestSheet(viewModel: viewModel)
            }
            .sheet(isPresented: Binding { tests.ending != nil } set: { if !$0 { tests.ending = nil } }) {
                if let ending = tests.ending, let test = tests.test(id: ending.testID) {
                    PriceTestEndSheet(
                        test: test,
                        ending: ending,
                        today: viewModel.today(),
                        onCancel: { tests.ending = nil },
                        onEnd: { Task { await viewModel.endPriceTest() } }
                    )
                }
            }
            .sheet(isPresented: Binding { tests.keepingTestID != nil } set: { if !$0 { tests.keepingTestID = nil } }) {
                if let id = tests.keepingTestID, let test = tests.test(id: id) {
                    PriceTestKeepSheet(
                        test: test,
                        onCancel: { tests.keepingTestID = nil },
                        onAdd: { Task { await viewModel.keepTestPrices() } }
                    )
                }
            }
    }
}
