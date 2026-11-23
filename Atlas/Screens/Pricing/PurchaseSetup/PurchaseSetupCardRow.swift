//
//  PurchaseSetupCardRow.swift
//  Atlas
//

import SwiftUI

/// What a product card shows under its prices besides them: its App
/// Review screenshot (`ReviewShotsCardPanel`), then its introductory offer
/// with Add Introductory Offer….
struct PurchaseSetupCardRow: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        let extras = viewModel.setup.extras[product.id]
        let state = viewModel.reviewShotState(for: product)
        VStack(alignment: .leading, spacing: Spacing.small) {
            ReviewShotsCardPanel(viewModel: viewModel, product: product)
            let addsOffer = viewModel.canAddIntroductoryOffer(to: product)
            if extras?.introductorySummary != nil || addsOffer || state == .unknown {
                HStack(spacing: Spacing.small) {
                    if let offer = extras?.introductorySummary {
                        Text("Intro: \(offer)")
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                            .accessibilityIdentifier("pricing.card.introductoryOffer")
                    }
                    Spacer(minLength: Spacing.small)
                    if addsOffer {
                        Button("Add Introductory Offer…") { viewModel.openIntroductoryOffer(for: product) }
                            .buttonStyle(.link)
                            .accessibilityIdentifier("pricing.card.addIntroductoryOffer")
                    }
                    if state == .unknown {
                        // Still reading what App Store Connect has: the
                        // file can be chosen all the same.
                        Button("Review Screenshot…") { viewModel.openReviewScreenshot(for: product) }
                            .buttonStyle(.link)
                            .accessibilityIdentifier("pricing.card.reviewScreenshot")
                    }
                }
            }
        }
        .controlSize(.regular)
        .accessibilityElement(children: .contain)
    }
}
