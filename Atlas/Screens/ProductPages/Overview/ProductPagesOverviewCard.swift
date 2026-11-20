//
//  ProductPagesOverviewCard.swift
//  Atlas
//

import SwiftUI

/// The Overview's way into Custom Product Pages: how many pages there are
/// and how they do, the suggested pages waiting, and Open.
struct ProductPagesOverviewCard: View {
    /// Nil until the section has read the pages.
    let summary: ProductPagesOverviewSummary?
    let onOpen: () -> Void

    var body: some View {
        Card {
            HStack(spacing: Spacing.xSmall) {
                OverviewCardTitle(title: String(localized: "Custom Product Pages"), systemImage: AppWorkspaceSection.productPages.systemImage)
                if let count = summary?.suggestionCount, count > 0 {
                    SuggestionBadge(count: count, isSmall: true)
                        .accessibilityLabel(Text(count == 1 ? "1 page suggested" : "\(count) pages suggested"))
                }
            }
            if let summary {
                Text(summary.line)
                    .font(.callout.weight(.semibold))
                    .accessibilityIdentifier("overview.pagesCard.line")
                if let best = summary.best {
                    Text(best)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Not read yet")
                    .font(.title3.weight(.semibold))
                Text("Other versions of the App Store page, each with its own link, for an audience, a campaign or a search.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open Custom Product Pages", action: onOpen)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("overview.pagesCard.open")
        }
        .accessibilityIdentifier("overview.pagesCard")
    }
}
