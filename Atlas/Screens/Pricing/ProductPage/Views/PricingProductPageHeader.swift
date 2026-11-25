//
//  PricingProductPageHeader.swift
//  Atlas
//

import SwiftUI

/// A product page's title row (board 73): its name, kind and product ID,
/// how many of its prices aren't pushed, and its base price. The price is
/// a grey skeleton while the product's prices are read.
struct PricingProductPageHeader: View {
    let viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        let card = viewModel.card(for: product)
        HStack(alignment: .bottom, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(product.name)
                    .atlasTextStyle(.title2)
                    .lineLimit(1)
                Text("\(PricingProductDetails.typeText(product)) · \(product.productID)")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let card, card.hasQueuedChanges {
                Pill(text: notPushedText(card.queuedCount), style: .accent)
                    .fixedSize()
                    .accessibilityIdentifier("pricing.product.notPushed")
            }
            basePrice(card)
        }
    }

    @ViewBuilder
    private func basePrice(_ card: PricingProductCard?) -> some View {
        let price = card?.basePrice ?? product.basePriceText
        let isReading = card == nil && viewModel.productErrors[product.id] == nil
        if price != nil || isReading {
            VStack(alignment: .trailing, spacing: Spacing.tiny) {
                if let price {
                    Text(price)
                        .atlasTextStyle(.title2)
                        .monospacedDigit()
                } else {
                    SkeletonBlock(width: 72, height: 18)
                }
                if let territory = viewModel.baseTerritoryName(for: product) {
                    Text(String(localized: "Base price · \(territory)", comment: "kind:label"))
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                } else {
                    Text(String(localized: "Base price", comment: "kind:label"))
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pricing.product.basePrice")
        }
    }

    /// "1 price not pushed", "2 prices not pushed".
    private func notPushedText(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 price not pushed", comment: "kind:label")
            : String(localized: "\(count) prices not pushed", comment: "kind:label")
    }
}
