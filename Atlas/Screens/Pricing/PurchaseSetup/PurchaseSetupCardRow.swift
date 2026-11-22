//
//  PurchaseSetupCardRow.swift
//  Atlas
//

import SwiftUI

/// The bottom of a product's card: its review screenshot's state (with
/// Review Screenshot…), its introductory offer or Add Introductory Offer…,
/// read from App Store Connect with the push's transport.
struct PurchaseSetupCardRow: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        let extras = viewModel.setup.extras[product.id]
        HStack(spacing: Spacing.small) {
            screenshotStatus(extras?.reviewScreenshot)
            if let offer = extras?.introductorySummary {
                Text("Intro: \(offer)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .accessibilityIdentifier("pricing.card.introductoryOffer")
            }
            Spacer(minLength: Spacing.small)
            if viewModel.canAddIntroductoryOffer(to: product) {
                Button("Add Introductory Offer…") { viewModel.openIntroductoryOffer(for: product) }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("pricing.card.addIntroductoryOffer")
            }
            Button("Review Screenshot…") { viewModel.openReviewScreenshot(for: product) }
                .buttonStyle(.link)
                .accessibilityIdentifier("pricing.card.reviewScreenshot")
        }
        .controlSize(.small)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func screenshotStatus(_ state: PurchaseReviewScreenshotState?) -> some View {
        if viewModel.hasQueuedReviewScreenshot(for: product) {
            Label("Review screenshot not pushed", systemImage: "photo")
                .font(.subheadline)
                .foregroundStyle(Palette.accent)
                .accessibilityIdentifier("pricing.card.reviewScreenshot.state")
        } else if let state {
            Label(state.title, systemImage: state.isUploaded ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(state.isUploaded ? Palette.label2 : Palette.warning)
                .lineLimit(1)
                .accessibilityIdentifier("pricing.card.reviewScreenshot.state")
        }
    }
}
