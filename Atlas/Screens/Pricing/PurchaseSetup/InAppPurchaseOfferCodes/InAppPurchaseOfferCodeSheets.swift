//
//  InAppPurchaseOfferCodeSheets.swift
//  Atlas
//

import SwiftUI

/// An in-app purchase's offer code sheets, shown from
/// `setup.inAppPurchaseOfferRoute`: New Offer Code…, and Add Custom Code…
/// or Add One-Time Codes… for one App Store Connect has (the subscription
/// sheets' `AddOfferCodesSheet`). Save Codes…'s save panel is
/// `SubscriptionOfferSheets`'.
struct InAppPurchaseOfferCodeSheets: ViewModifier {
    @Bindable var viewModel: PricingViewModel

    func body(content: Content) -> some View {
        @Bindable var setup = viewModel.setup
        content
            .sheet(item: $setup.inAppPurchaseOfferRoute) { route in
                sheet(for: route)
            }
    }

    @ViewBuilder
    private func sheet(for route: InAppPurchaseOfferCodeRoute) -> some View {
        let close = { viewModel.closeInAppPurchaseOfferSheet() }
        switch route {
        case let .newOfferCode(purchase):
            InAppPurchaseOfferCodeSheet(
                purchase: purchase,
                problems: { viewModel.problems(for: $0, purchase: purchase) },
                onCancel: close,
                onAdd: { viewModel.queueInAppPurchaseOfferCode($0, for: purchase) }
            )
        case let .customCode(purchase, code), let .oneTimeCodes(purchase, code):
            AddOfferCodesSheet(
                kind: route.isCustomCode ? .custom : .oneTime,
                offer: AddOfferCodesSheet.Offer(
                    name: code.name, termsSummary: code.terms.summary(purchasePrice: purchase.basePrice), codesSummary: code.codesSummary
                ),
                customProblems: { viewModel.problems(for: $0, code: code, purchase: purchase) },
                batchProblems: { viewModel.problems(for: $0, code: code) },
                onCancel: close,
                onAddCustom: { viewModel.queueCustomCode($0, for: code, purchase: purchase) },
                onAddBatch: { viewModel.queueOneTimeCodes($0, for: code, purchase: purchase) }
            )
        }
    }
}
