//
//  SubscriptionOfferActions.swift
//  Atlas
//

import SwiftUI

/// What the Offers tab does with the selected offer App Store Connect has,
/// above its details: Change Prices… and Delete… for a promotional offer,
/// Edit… and Delete… for a win-back offer, and for an offer code its codes
/// (Save Codes… for one-time ones), Add Custom Code…, Add One-Time Codes…
/// and Deactivate…. Each queues a change in Review & Push; while one waits,
/// it says so.
struct SubscriptionOfferActions: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct
    let offerID: SubscriptionOffer.ID

    @State private var confirmation: Confirmation?

    private enum Confirmation: Identifiable {
        case deletePromotional(ExistingPromotionalOffer)
        case deleteWinBack(ExistingWinBackOffer)
        case deactivate(OfferCodeChangeBuilder.Target, ExistingOfferCode)

        var id: String {
            switch self {
            case let .deletePromotional(offer): "promotional.\(offer.id)"
            case let .deleteWinBack(offer): "winBack.\(offer.id)"
            case let .deactivate(target, code): "deactivate.\(code.id).\(target.resourceID(in: code))"
            }
        }
    }

    var body: some View {
        Group {
            if let offer = viewModel.promotionalOffer(id: offerID, of: product) {
                promotional(offer)
            } else if let offer = viewModel.winBackOffer(id: offerID, of: product) {
                winBack(offer)
            } else if let code = viewModel.offerCode(id: offerID, of: product) {
                offerCode(code)
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.medium)
        .confirmationDialog(confirmationTitle, isPresented: isConfirming, presenting: confirmation) { item in
            Button(confirmButtonTitle(item), role: .destructive) { confirm(item) }
                .accessibilityIdentifier("pricing.offerActions.confirm")
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(confirmMessage(item))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.offerActions")
    }

    // MARK: - Kinds

    private func promotional(_ offer: ExistingPromotionalOffer) -> some View {
        let changeID = PromotionalOfferChangeBuilder.changeID(appID: viewModel.app.id, productID: product.productID, identifier: offer.identifier)
        return bar(waiting: viewModel.hasQueuedChange(changeID)) {
            Button("Change Prices…") { viewModel.open(.promotionalPrices(product, offer)) }
                .accessibilityIdentifier("pricing.offerActions.prices")
            Button("Delete…", role: .destructive) { confirmation = .deletePromotional(offer) }
                .accessibilityIdentifier("pricing.offerActions.delete")
        }
    }

    private func winBack(_ offer: ExistingWinBackOffer) -> some View {
        let changeID = WinBackOfferChangeBuilder.changeID(appID: viewModel.app.id, productID: product.productID, offerID: offer.offerID)
        return bar(waiting: viewModel.hasQueuedChange(changeID)) {
            Button("Edit…") { viewModel.open(.winBackSettings(product, offer)) }
                .accessibilityIdentifier("pricing.offerActions.edit")
            Button("Delete…", role: .destructive) { confirmation = .deleteWinBack(offer) }
                .accessibilityIdentifier("pricing.offerActions.delete")
        }
    }

    private func offerCode(_ code: ExistingOfferCode) -> some View {
        let changeID = OfferCodeChangeBuilder.changeID(appID: viewModel.app.id, productID: product.productID, offerCodeID: code.id, what: "deactivate")
        return VStack(alignment: .leading, spacing: Spacing.small) {
            bar(waiting: viewModel.hasQueuedChange(changeID)) {
                Button("Add Custom Code…") { viewModel.open(.customCode(product, code)) }
                    .disabled(!code.isActive)
                    .accessibilityIdentifier("pricing.offerActions.addCustomCode")
                Button("Add One-Time Codes…") { viewModel.open(.oneTimeCodes(product, code)) }
                    .disabled(!code.isActive)
                    .accessibilityIdentifier("pricing.offerActions.addOneTimeCodes")
                if code.isActive {
                    Button("Deactivate…", role: .destructive) { confirmation = .deactivate(.offerCode, code) }
                        .accessibilityIdentifier("pricing.offerActions.deactivate")
                }
            }
            if !code.customCodes.isEmpty || !code.oneTimeCodes.isEmpty {
                OfferCodeCodesList(
                    code: code,
                    onSave: { batch in Task { await viewModel.saveCodes(batch, of: code) } },
                    onDeactivate: { confirmation = .deactivate($0, code) }
                )
            }
        }
    }

    private func bar(waiting: Bool, @ViewBuilder buttons: () -> some View) -> some View {
        HStack(spacing: Spacing.small) {
            buttons()
            Spacer(minLength: Spacing.small)
            if waiting {
                Label("A change waits in Review & Push", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("pricing.offerActions.waiting")
            }
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
    }

    // MARK: - Confirmation

    private var isConfirming: Binding<Bool> {
        Binding { confirmation != nil } set: { if !$0 { confirmation = nil } }
    }

    private var confirmationTitle: String {
        guard let confirmation else { return "" }
        return switch confirmation {
        case let .deletePromotional(offer): String(localized: "Delete “\(offer.name)”?")
        case let .deleteWinBack(offer): String(localized: "Delete “\(offer.referenceName)”?")
        case let .deactivate(.offerCode, code): String(localized: "Deactivate “\(code.name)”?")
        case let .deactivate(.customCode(custom), _): String(localized: "Deactivate the code \(custom.code)?")
        case .deactivate(.oneTimeCodes, _): String(localized: "Deactivate these one-time codes?")
        }
    }

    private func confirmButtonTitle(_ item: Confirmation) -> String {
        switch item {
        case .deletePromotional, .deleteWinBack: String(localized: "Add Deletion to Review & Push")
        case .deactivate: String(localized: "Add to Review & Push")
        }
    }

    private func confirmMessage(_ item: Confirmation) -> String {
        switch item {
        case .deletePromotional:
            String(localized: "Once you push, your app can’t offer it any more. People who redeemed it keep it.")
        case .deleteWinBack:
            String(localized: "Once you push, Apple stops showing it. People who redeemed it keep it.")
        case .deactivate:
            String(localized: "After you push, these codes stop working permanently. People who redeemed one keep their offer.")
        }
    }

    private func confirm(_ item: Confirmation) {
        switch item {
        case let .deletePromotional(offer): viewModel.deletePromotionalOffer(offer, of: product)
        case let .deleteWinBack(offer): viewModel.deleteWinBackOffer(offer, of: product)
        case let .deactivate(target, code): viewModel.deactivate(target, in: code, of: product)
        }
        confirmation = nil
    }
}
