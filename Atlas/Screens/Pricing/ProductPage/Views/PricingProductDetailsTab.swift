//
//  PricingProductDetailsTab.swift
//  Atlas
//

import SwiftUI

/// A product page's Details tab (board 73): type, product ID, subscription
/// group, base price, where it's available and Family Sharing. A value
/// still being read is a grey line; a read that failed says so once under
/// the list, with Try Again.
struct PricingProductDetailsTab: View {
    let viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        let rows = viewModel.productDetails(for: product).rows
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.large, verticalSpacing: 0) {
                ForEach(rows) { row in
                    GridRow {
                        Text(row.title)
                            .foregroundStyle(Palette.label2)
                        value(row)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .atlasTextStyle(.callout)
                    .padding(.vertical, Spacing.medium)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pricing.product.details.\(row.id)")
                    if row.id != rows.last?.id {
                        Divider()
                            .gridCellColumns(2)
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .background(Palette.raised, in: shape)
            .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
            if let failure = viewModel.productFacts.failure(for: product.id) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    ErrorCopyMessage(copy: failure)
                    Spacer(minLength: Spacing.small)
                    Button("Try Again") { Task { await viewModel.loadProductFacts(for: product) } }
                        .accessibilityIdentifier("pricing.product.details.tryAgain")
                }
                .accessibilityIdentifier("pricing.product.details.error")
            }
        }
        .padding(.bottom, Spacing.large)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.product.details")
        .task(id: product.id) { await viewModel.loadProductFacts(for: product) }
    }

    @ViewBuilder
    private func value(_ row: PricingProductDetails.Row) -> some View {
        if let value = row.value {
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            SkeletonBlock(width: 140)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}
