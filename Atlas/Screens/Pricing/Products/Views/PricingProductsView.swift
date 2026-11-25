//
//  PricingProductsView.swift
//  Atlas
//

import SwiftUI

/// Pricing's Prices page: the header, the app's own price and
/// availability, the price suggestions with Accept All n, a card per
/// product, and "Preview in" beside them (under them when the window is
/// narrow).
struct PricingProductsView: View {
    @Bindable var viewModel: PricingViewModel

    @State private var width: CGFloat = 0
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                PricingHeader(viewModel: viewModel)
                if let appPriceAvailability = viewModel.appPriceAvailability {
                    AppPriceAvailabilityCards(model: appPriceAvailability)
                }
                // One banner: a new subscription's recommendations waiting
                // for review come first.
                if let product = viewModel.reviewLaterProducts.first {
                    reviewLaterBanner(product)
                } else if viewModel.openPriceSuggestionCount > 0 {
                    banner
                }
                ReviewShotsBanner(viewModel: viewModel)
                let isWide = width >= 560 + PricingPreviewIn.width + Spacing.large
                let layout = isWide
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.large))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.large))
                layout {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        cards
                        if !viewModel.queuedNewProducts.isEmpty {
                            QueuedNewSubscriptionsList(viewModel: viewModel)
                        }
                    }
                    // Clicking a product opens its page on that country.
                    PricingPreviewIn(viewModel: viewModel) { id, territoryID in
                        viewModel.openProduct(id, territory: territoryID)
                    }
                }
            }
            .task(id: viewModel.catalog?.products.map(\.id)) { await viewModel.loadPurchaseExtras() }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.large)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 - 2 * Spacing.xLarge }
        }
        .leavesChatRoom()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("pricing.products")
        .sheet(isPresented: isPreviewing) {
            ReviewShotsPreviewSheet(viewModel: viewModel)
                .pageControlSize()
        }
    }

    /// Show Larger on a card's review screenshot.
    private var isPreviewing: Binding<Bool> {
        Binding {
            viewModel.setup.reviewShotsPreviewProductID != nil
        } set: {
            if !$0 { viewModel.setup.reviewShotsPreviewProductID = nil }
        }
    }

    /// A new subscription added with Apple's prices and the recommendations
    /// for later: what waits, and Review….
    private func reviewLaterBanner(_ product: PricingProduct) -> some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.reviewLaterTitle(product))
                    .font(.callout.weight(.semibold))
                Text(viewModel.reviewLaterDetail(product))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Review…", comment: "kind:button")) {
                viewModel.reviewLaterProductID = product.id
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("pricing.reviewLater.review")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.reviewLater")
    }

    private var banner: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            Text(viewModel.priceSuggestionsBannerText)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                let countries = viewModel.productCards.reduce(0) { $0 + $1.suggestedCount }
                pro.require(.recommendedPrices(countries: countries)) {
                    Task { await viewModel.acceptAllPriceSuggestions() }
                }
            } label: {
                HStack(spacing: Spacing.xSmall) {
                    Text("Accept All")
                    SuggestionBadge(count: viewModel.openPriceSuggestionCount)
                    if pro.isFree { ProChip() }
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityLabel(Text("Accept All, \(viewModel.openPriceSuggestionCount) suggested"))
            .accessibilityIdentifier("pricing.acceptAll")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.suggestionsBanner")
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(viewModel.catalog?.products ?? []) { product in
                if let card = viewModel.card(for: product) {
                    PricingProductCardView(
                        card: card,
                        onOpenPage: { viewModel.openProduct(product.id) },
                        onShowCountries: { viewModel.showSuggestedCountries(productID: product.id) },
                        onDismiss: { viewModel.dismissPriceSuggestion(productID: product.id) },
                        onAccept: {
                            // Prices for many countries at once are Pro's;
                            // one country's stays free.
                            let accept = { _ = Task.immediate { await viewModel.acceptPriceSuggestion(productID: product.id) } }
                            if card.suggestedCount > 1 {
                                pro.require(.recommendedPrices(countries: card.suggestedCount), then: accept)
                            } else {
                                accept()
                            }
                        },
                        settlesOnAccept: !(card.suggestedCount > 1 && pro.isFree),
                        setupRow: AnyView(PurchaseSetupCardRow(viewModel: viewModel, product: product))
                    )
                    // Effect 2: the spark sits still on the card being
                    // captured.
                    .aiWorking(viewModel.reviewShotState(for: product).isWorking)
                } else if let message = viewModel.productErrors[product.id] {
                    unavailable(product, message: message)
                } else {
                    placeholder(product)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    /// A card whose prices haven't arrived: its name and product ID, with
    /// grey blocks where the price and the country bar go (no spinner).
    private func placeholder(_ product: PricingProduct) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(alignment: .top, spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(product.name).atlasTextStyle(.title3)
                    Text(product.productID).atlasTextStyle(.subheadline).foregroundStyle(Palette.label2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.tiny) {
                    SkeletonBlock(width: 72, height: 16)
                    SkeletonBlock(width: 96, height: 8)
                }
            }
            SkeletonBlock(height: 6)
            SkeletonBlock(width: 220, height: 8)
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(product.name), prices loading"))
    }

    private func unavailable(_ product: PricingProduct, message: String) -> some View {
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.body.weight(.semibold))
                Text(message).font(.subheadline).foregroundStyle(Palette.label2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if viewModel.unreadProductIDs.contains(product.id) {
                // Apple's server failed on this product's prices alone.
                Button("Try Again") { Task { await viewModel.retryProduct(productID: product.id) } }
                    .controlSize(.regular)
                    .accessibilityLabel(Text("Read \(product.name)’s prices again"))
                    .accessibilityIdentifier("pricing.card.tryAgain")
            } else {
                Button(String(localized: "Open Product", comment: "kind:button")) { viewModel.openProduct(product.id) }
                    .plainButton()
                    .controlSize(.regular)
                    .accessibilityLabel(Text("Open \(product.name)’s page", comment: "kind:accessibility-label"))
                    .accessibilityIdentifier("pricing.card.openUnavailable")
            }
        }
        .padding(14)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}
