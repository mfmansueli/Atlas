//
//  PricingViewModel+ProductPage.swift
//  Atlas
//

import Foundation

// A product's page inside Pricing (board 73): the top of its card, Show
// Countries and "Preview in" open it; the breadcrumb, ⌘[ and Pricing in the
// sidebar go back to the cards. Opening it selects the product, so its
// Offers tab reads that product's offers (`loadOffers()`).
extension PricingViewModel {
    /// The product whose page shows, if it's still in the catalog.
    var pageProduct: PricingProduct? {
        productRoute.flatMap { catalog?.product(id: $0.productID) }
    }

    /// Opens `productID`'s page on Prices by Country; `territory` (alpha-3)
    /// is the country it selects and scrolls to, `filter` the one it shows.
    func openProduct(
        _ productID: PricingProduct.ID,
        territory: String? = nil,
        filter: PricesByCountryFilter = .all,
        tab: PricingProductTab = .pricesByCountry
    ) {
        guard catalog?.product(id: productID) != nil else { return }
        productRoute = PricingProductRoute(productID: productID, tab: tab, filter: filter, focusedTerritory: territory)
        Task { await select(productID: productID) }
    }

    /// The product before (−1) or after (+1) the open one, in the cards'
    /// order; nil at either end.
    func adjacentProduct(_ offset: Int) -> PricingProduct? {
        guard let products = catalog?.products, let id = productRoute?.productID,
              let index = products.firstIndex(where: { $0.id == id })
        else { return nil }
        let next = index + offset
        return products.indices.contains(next) ? products[next] : nil
    }

    /// ⌃ ⌄ in the breadcrumb (⌥⌘↑ / ⌥⌘↓): the previous or next product's
    /// page on the same tab, without going back to the list.
    func openAdjacentProduct(_ offset: Int) {
        guard let product = adjacentProduct(offset) else { return }
        let tab = productRoute?.tab ?? .pricesByCountry
        let filter = productRoute?.filter ?? .all
        openProduct(product.id, filter: filter, tab: tab)
    }

    /// Back to the product cards.
    func closeProduct() {
        productRoute = nil
    }

    /// Show Countries on a price suggestion: the product's page with the
    /// suggested prices alone.
    func showSuggestedCountries(productID: PricingProduct.ID) {
        openProduct(productID, filter: .suggested)
    }

    /// Pricing chosen again in the sidebar (or ⌘7) while it shows: back to
    /// the cards from a product's page or its prices.
    func showProductList() {
        closeProduct()
    }

    // MARK: - The page

    /// The open product's matrix, once `select(productID:)` has read it.
    func pageMatrix(for productID: PricingProduct.ID) -> PriceMatrixModel? {
        guard let matrix, matrix.product.id == productID, !isLoadingSheet else { return nil }
        return matrix
    }

    /// Why the open product's prices didn't load, once its own read failed.
    func pageError(for productID: PricingProduct.ID) -> String? {
        guard selectedProductID == productID, !isLoadingSheet else { return nil }
        return sheetError ?? productErrors[productID]
    }

    /// The purple count on Prices by Country: the countries with a price
    /// suggestion still open.
    func openSuggestionCount(for product: PricingProduct) -> Int {
        guard let card = card(for: product), card.suggestion != nil else { return 0 }
        return card.suggestedCount
    }

    /// "United States": the base price's country, once the product's prices
    /// are read.
    func baseTerritoryName(for product: PricingProduct) -> String? {
        productMatrices[product.id]?.rows.first(where: \.isBase)?.territory.name
    }

    /// The Review Screenshot tab's status line.
    func reviewScreenshotStatus(for product: PricingProduct) -> ProductReviewScreenshotStatus {
        ProductReviewScreenshotStatus.make(reviewShotState(for: product))
    }

    /// The Details tab's rows.
    func productDetails(for product: PricingProduct) -> PricingProductDetails {
        let card = card(for: product)
        return PricingProductDetails.make(
            product: product,
            group: catalog?.group(containing: product.id),
            basePrice: card.flatMap { card in card.basePrice.map { "\($0) \(card.baseTerritoryText)" } },
            isReadingPrices: card == nil && productErrors[product.id] == nil,
            facts: productFacts.state(for: product.id),
            territoryTotal: TerritoryCatalog.standard.count,
            commission: strategy.commission
        )
    }

    /// Reads the product's availability and Family Sharing once.
    func loadProductFacts(for product: PricingProduct) async {
        await productFacts.load(product, transport: setup.transport)
    }

    /// Reads the product's review screenshot in App Store Connect, unless
    /// it's read.
    func loadReviewScreenshot(for product: PricingProduct) async {
        refreshReviewShots()
        await setup.load([product])
        refreshReviewShots()
    }
}
