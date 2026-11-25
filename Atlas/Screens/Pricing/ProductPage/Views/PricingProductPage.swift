//
//  PricingProductPage.swift
//  Atlas
//

import SwiftUI

/// One product's page inside Pricing (board 73), in place of the product
/// cards: the breadcrumb back to Pricing (⌘[) with the previous and next
/// product (⌥⌘↑ / ⌥⌘↓), its name and base price, and Prices by Country ·
/// Results · Offers · Review Screenshot · Details, Prices by Country with
/// the count of its open price suggestions. At 860 × 560 the name and base
/// price move into the breadcrumb row. The page owns the Prices by Country
/// filter and the country it focuses, in `PricingViewModel.productRoute`.
struct PricingProductPage: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < Metrics.productPageCompactWidth
                || proxy.size.height < Metrics.productPageCompactHeight
            page(isCompact: isCompact)
                .onChange(of: isCompact, initial: true) { viewModel.pricesByCountry.isCompact = isCompact }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.product")
    }

    private func page(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? Spacing.small : Spacing.medium) {
            PricingProductBreadcrumb(
                productName: product.name,
                basePrice: isCompact ? basePrice : nil,
                hasPrevious: viewModel.adjacentProduct(-1) != nil,
                hasNext: viewModel.adjacentProduct(1) != nil,
                onBack: viewModel.closeProduct,
                onPrevious: { viewModel.openAdjacentProduct(-1) },
                onNext: { viewModel.openAdjacentProduct(1) }
            )
            if !isCompact {
                PricingProductPageHeader(viewModel: viewModel, product: product)
            }
            BadgedSegments(
                label: String(localized: "Product", comment: "kind:accessibility-label"),
                options: PricingProductTab.allCases.map { tab in
                    (value: tab, title: tab.title, count: tab == .pricesByCountry ? viewModel.openSuggestionCount(for: product) : 0)
                },
                selection: tab
            )
            .accessibilityIdentifier("pricing.product.tabs")
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, isCompact ? Spacing.large : Spacing.xLarge)
        .padding(.top, isCompact ? Spacing.small : Spacing.medium)
        // Under the page, the chat's pill: the selection bar's actions and
        // the last rows end above it (the prototype's `padding-bottom: 58px`).
        .leavesChatRoom(.bottomEdge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var basePrice: String? {
        viewModel.card(for: product)?.basePrice ?? product.basePriceText
    }

    @ViewBuilder
    private var content: some View {
        switch tab.wrappedValue {
        case .pricesByCountry:
            PricesByCountryView(viewModel: viewModel, productID: product.id, filter: filter, focusedTerritory: focusedTerritory)
        case .results:
            PricingResultsView(viewModel: viewModel)
                .padding(.bottom, Spacing.large)
        case .offers:
            PricingProductOffersTab(viewModel: viewModel, product: product)
                .padding(.bottom, Spacing.large)
        case .reviewScreenshot:
            ScrollView {
                PricingProductReviewScreenshotTab(viewModel: viewModel, product: product)
                    .padding(.bottom, Spacing.large)
            }
        case .details:
            ScrollView {
                PricingProductDetailsTab(viewModel: viewModel, product: product)
            }
        }
    }

    private var tab: Binding<PricingProductTab> {
        Binding {
            viewModel.productRoute?.tab ?? .pricesByCountry
        } set: {
            viewModel.productRoute?.tab = $0
        }
    }

    private var filter: Binding<PricesByCountryFilter> {
        Binding {
            viewModel.productRoute?.filter ?? .all
        } set: {
            viewModel.productRoute?.filter = $0
        }
    }

    private var focusedTerritory: Binding<String?> {
        Binding {
            viewModel.productRoute?.focusedTerritory
        } set: {
            viewModel.productRoute?.focusedTerritory = $0
        }
    }
}
