//
//  PriceTestSheet.swift
//  Atlas
//

import SwiftUI

/// The one Test a Price sheet (board 76): the setup, then its
/// confirmation. Results' Test a Price…, the strategy pop-up and the
/// assistant's Set Up Test… all open it.
struct PriceTestSheet: View {
    let viewModel: PricingViewModel

    var body: some View {
        if let setup = viewModel.priceTests.setup {
            if setup.isConfirming, let plan = viewModel.priceTestPlan, plan.canContinue {
                PriceTestConfirmView(
                    plan: plan,
                    today: viewModel.today(),
                    onBack: { viewModel.priceTests.setup?.isConfirming = false },
                    onAdd: { Task { await viewModel.queuePriceTest() } }
                )
            } else {
                PriceTestSetupForm(viewModel: viewModel, setup: binding(setup))
            }
        }
    }

    private func binding(_ current: PriceTestSetup) -> Binding<PriceTestSetup> {
        Binding { viewModel.priceTests.setup ?? current } set: { viewModel.priceTests.setup = $0 }
    }
}
