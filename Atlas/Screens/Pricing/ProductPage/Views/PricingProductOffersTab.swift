//
//  PricingProductOffersTab.swift
//  Atlas
//

import SwiftUI

/// A product page's Offers tab (board 73): a subscription's introductory,
/// promotional and win-back offers and offer codes with their actions
/// (`PricingOffersView`). A one-time purchase has no subscription offers;
/// its offer codes stay under that line (`InAppPurchaseOffersView`). Grey
/// rows while the product's prices and offers are read.
struct PricingProductOffersTab: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if product.isInAppPurchase {
                Label {
                    Text(String(localized: "One-time purchases don’t have subscription offers.", comment: "kind:empty"))
                } icon: {
                    Image(systemName: "tag")
                }
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                // No fixedSize: wrapped at the window's narrowest width, the
                // line would make the page taller than the window.
                .lineLimit(2)
                .accessibilityIdentifier("pricing.product.offers.oneTime")
            }
            panel
        }
    }

    private var panel: some View {
        Group {
            if let matrix = viewModel.pageMatrix(for: product.id) {
                if product.isInAppPurchase {
                    InAppPurchaseOffersView(viewModel: viewModel, matrix: matrix)
                } else {
                    PricingOffersView(viewModel: viewModel, matrix: matrix)
                }
            } else if let message = viewModel.pageError(for: product.id) {
                ContentUnavailableView {
                    Label("Offers couldn’t load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
                .accessibilityIdentifier("pricing.product.offers.error")
            } else {
                PricingOffersSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.raised, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}
