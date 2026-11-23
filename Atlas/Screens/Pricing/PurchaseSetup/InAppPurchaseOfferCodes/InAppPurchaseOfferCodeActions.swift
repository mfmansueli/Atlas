//
//  InAppPurchaseOfferCodeActions.swift
//  Atlas
//

import SwiftUI

/// What an in-app purchase's Offers tab does with the selected offer code
/// App Store Connect has, above its details: Add Custom Code…, Add
/// One-Time Codes… and Deactivate…, then its codes (Save Codes… for
/// one-time ones, Deactivate… for each). Each queues a change in Review &
/// Push; while a deactivation waits, it says so.
struct InAppPurchaseOfferCodeActions: View {
    @Bindable var viewModel: PricingViewModel
    let purchase: PricingProduct
    let code: ExistingInAppPurchaseOfferCode

    @State private var deactivating: OfferCodeChangeBuilder.Target?

    var body: some View {
        let changeID = InAppPurchaseOfferCodeChangeBuilder.changeID(
            appID: viewModel.app.id, productID: purchase.productID, offerCodeID: code.id, what: "deactivate"
        )
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Button("Add Custom Code…") { viewModel.openInAppPurchaseOffer(.customCode(purchase, code)) }
                    .disabled(!code.isActive)
                    .accessibilityIdentifier("pricing.iapOfferActions.addCustomCode")
                Button("Add One-Time Codes…") { viewModel.openInAppPurchaseOffer(.oneTimeCodes(purchase, code)) }
                    .disabled(!code.isActive)
                    .accessibilityIdentifier("pricing.iapOfferActions.addOneTimeCodes")
                if code.isActive {
                    Button("Deactivate…", role: .destructive) { deactivating = .offerCode }
                        .accessibilityIdentifier("pricing.iapOfferActions.deactivate")
                }
                Spacer(minLength: Spacing.small)
                if viewModel.hasQueuedChange(changeID) {
                    Label("A change waits in Review & Push", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("pricing.iapOfferActions.waiting")
                }
            }
            .controlSize(.regular)
            .buttonBorderShape(.capsule)
            if !code.customCodes.isEmpty || !code.oneTimeCodes.isEmpty {
                OfferCodeCodesList(
                    customCodes: code.customCodes, oneTimeCodes: code.oneTimeCodes, isActive: code.isActive,
                    onSave: { batch in Task { await viewModel.saveCodes(batch, of: code) } },
                    onDeactivate: { deactivating = $0 }
                )
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.medium)
        .confirmationDialog(confirmationTitle, isPresented: isConfirming, presenting: deactivating) { target in
            Button("Add to Review & Push", role: .destructive) {
                viewModel.deactivate(target, in: code, of: purchase)
                deactivating = nil
            }
            .accessibilityIdentifier("pricing.iapOfferActions.confirm")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Once you push, those codes stop redeeming, and they can’t be turned back on. People who redeemed one keep their purchase.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.iapOfferActions")
    }

    private var isConfirming: Binding<Bool> {
        Binding { deactivating != nil } set: { if !$0 { deactivating = nil } }
    }

    private var confirmationTitle: String {
        switch deactivating {
        case .offerCode: String(localized: "Deactivate “\(code.name)”?")
        case let .customCode(custom): String(localized: "Deactivate the code \(custom.code)?")
        case .oneTimeCodes: String(localized: "Deactivate these one-time codes?")
        case nil: ""
        }
    }
}
