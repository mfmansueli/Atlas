//
//  PurchaseSetupSheets.swift
//  Atlas
//

import SwiftUI

/// Pricing's Create In-App Purchase, Add Introductory Offer… and Review
/// Screenshot… sheets, shown from the view model's `setup`.
struct PurchaseSetupSheets: ViewModifier {
    @Bindable var viewModel: PricingViewModel

    func body(content: Content) -> some View {
        @Bindable var setup = viewModel.setup
        content
            .sheet(isPresented: $setup.isNewInAppPurchaseSheetPresented) {
                NewInAppPurchaseSheet(
                    appID: viewModel.app.id,
                    appName: viewModel.app.name,
                    initial: viewModel.newInAppPurchaseDefaults(),
                    problems: viewModel.problems(for:),
                    onCancel: { setup.isNewInAppPurchaseSheetPresented = false },
                    onAdd: viewModel.queueNewInAppPurchase
                )
            }
            .sheet(item: $setup.introductoryOfferTarget) { target in
                IntroductoryOfferSheet(
                    target: target,
                    problems: { viewModel.problems(for: $0, target: target) },
                    onCancel: { setup.introductoryOfferTarget = nil },
                    onAdd: { viewModel.queueIntroductoryOffer($0, for: target) }
                )
            }
            .sheet(item: $setup.reviewScreenshotTarget) { target in
                ReviewScreenshotSheet(
                    appID: viewModel.app.id,
                    target: target,
                    current: current(for: target),
                    onCancel: { setup.reviewScreenshotTarget = nil },
                    onAdd: { viewModel.queueReviewScreenshot($0, for: target) }
                )
            }
    }

    private func current(for target: PurchaseSetupTarget) -> PurchaseReviewScreenshotState? {
        guard case let .existing(product) = target.place else { return nil }
        return viewModel.reviewScreenshotState(of: product)
    }
}
