//
//  ProductPageDefaultRow.swift
//  Atlas
//

import SwiftUI

/// The default product page, tinted: what everyone else sees, and the
/// reference every page's download rate is compared with.
struct ProductPageDefaultRow: View {
    @Bindable var viewModel: ProductPagesViewModel
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        name
                        Spacer(minLength: Spacing.small)
                        status
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        ProductPageFunnelText(numbers: viewModel.defaultNumbers, emptyText: String(localized: "No numbers yet"))
                        rate
                    }
                }
                .padding(.vertical, Spacing.small)
            } else {
                HStack(spacing: Spacing.medium) {
                    name.frame(minWidth: ProductPageRow.nameMinimum, maxWidth: .infinity, alignment: .leading)
                    status.frame(width: ProductPageRow.statusWidth, alignment: .leading)
                    ProductPageFunnelText(numbers: viewModel.defaultNumbers, emptyText: String(localized: "No numbers yet"))
                        .frame(width: ProductPageRow.funnelWidth, alignment: .leading)
                    rate.frame(width: ProductPageRow.rateWidth, alignment: .leading)
                    Color.clear.frame(width: ProductPageRow.copyWidth, height: 1)
                }
                .frame(minHeight: 52)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .background(Palette.fill1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pages.row.default")
    }

    private var name: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Default product page")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(isCompact ? 2 : 1)
                .fixedSize(horizontal: false, vertical: isCompact)
        }
    }

    private var subtitle: String {
        let languages = ReviewText.languages(max(viewModel.defaultPage.languages.count, 1))
        return String(localized: "What everyone else sees · \(languages) · the reference for every page below")
    }

    private var status: some View {
        Pill(text: String(localized: "On the App Store"), style: .decrease)
            .fixedSize()
    }

    @ViewBuilder
    private var rate: some View {
        if let rate = viewModel.defaultNumbers?.downloadRate {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text(ProductPageNumbersText.rate(rate))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("the reference")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .lineLimit(1)
        } else {
            // Keeps the column under its header (an empty view takes no room).
            Color.clear.frame(height: 1)
        }
    }
}
