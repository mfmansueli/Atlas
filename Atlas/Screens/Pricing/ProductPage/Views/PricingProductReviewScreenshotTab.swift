//
//  PricingProductReviewScreenshotTab.swift
//  Atlas
//

import SwiftUI

/// A product page's Review Screenshot tab (board 73): where its App Review
/// screenshot is (missing, a capture ready, accepted, in App Store
/// Connect) and Review Screenshot… to choose one. The status is a grey
/// line while App Store Connect is read.
struct PricingProductReviewScreenshotTab: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    @State private var isReading = true

    var body: some View {
        let status = viewModel.reviewScreenshotStatus(for: product)
        Card {
            Text("Review screenshot")
                .atlasTextStyle(.headline)
            if status == .notRead, isReading {
                SkeletonBlock(width: 280, height: 12)
                    .accessibilityIdentifier("pricing.product.reviewScreenshot.skeleton")
            } else {
                statusLine(status)
            }
            Text(String(localized: "App Review sees it with the product. People on the App Store don’t.", comment: "kind:label"))
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Review Screenshot…", comment: "kind:button")) {
                viewModel.openReviewScreenshot(for: product)
            }
            .secondaryButton()
            .padding(.top, Spacing.xxSmall)
            .accessibilityIdentifier("pricing.product.reviewScreenshot.choose")
        }
        .accessibilityIdentifier("pricing.product.reviewScreenshot")
        .task(id: product.id) {
            isReading = true
            await viewModel.loadReviewScreenshot(for: product)
            isReading = false
        }
    }

    private func statusLine(_ status: ProductReviewScreenshotStatus) -> some View {
        Label {
            Text(status.text)
                .foregroundStyle(status.tone == .assistant ? Palette.ai : Palette.label)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol(for: status.tone))
                .foregroundStyle(color(for: status.tone))
        }
        .atlasTextStyle(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(status.text))
        .accessibilityIdentifier("pricing.product.reviewScreenshot.status")
    }

    private func symbol(for tone: ProductReviewScreenshotStatus.Tone) -> String {
        switch tone {
        case .needsYou: StatusSymbol.needsYou.symbol
        case .done: StatusSymbol.done.symbol
        case .notPushed: "clock"
        case .assistant: "sparkles"
        case .neutral: StatusSymbol.info.symbol
        }
    }

    private func color(for tone: ProductReviewScreenshotStatus.Tone) -> Color {
        switch tone {
        case .needsYou: Palette.warn
        case .done: Palette.ok
        case .notPushed: Palette.accentText
        case .assistant: Palette.ai
        case .neutral: Palette.label2
        }
    }
}
