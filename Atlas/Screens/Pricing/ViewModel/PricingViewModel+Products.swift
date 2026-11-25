//
//  PricingViewModel+Products.swift
//  Atlas
//

import Foundation

// Pricing's Prices page: a card per product with its open price suggestion
// (Accept, Dismiss, Show Countries), Accept All above them, and "Preview
// in" beside them (PricingViewModel+PreviewIn). Every product's prices are read once the catalog
// is here, one product at a time; accepting follows the strategy for that
// product, as Apply Suggested Prices… does, and nothing is pushed.
extension PricingViewModel {
    // MARK: - Loading

    /// Reads every product's prices for the cards, after the selected one.
    func startLoadingProducts() {
        productsTask?.cancel()
        areProductsLoaded = false
        productsTask = Task { [weak self] in await self?.loadProducts() }
    }

    func loadProducts() async {
        guard let catalog else { return }
        let ids = Set(catalog.products.map(\.id))
        productMatrices = productMatrices.filter { ids.contains($0.key) }
        unreadProductIDs.formIntersection(ids)
        for product in catalog.products {
            guard !Task.isCancelled else { return }
            // The selected product's prices, unless that read just failed:
            // then they're read again here.
            if let matrix, matrix.product.id == product.id, sheetError == nil {
                productMatrices[product.id] = makeMatrix(product: product, sheet: matrix.sheet)
                productErrors[product.id] = nil
                unreadProductIDs.remove(product.id)
                continue
            }
            await loadCard(of: product)
            guard !Task.isCancelled else { return }
        }
        areProductsLoaded = true
        // Today's prices show on every card first; then Apple's price
        // points, one product at a time, before any suggestion.
        await loadGrids()
    }

    /// A card's Try Again, after Apple's server failed on its prices: reads
    /// that product alone again.
    func retryProduct(productID: String) async {
        guard let product = catalog?.product(id: productID) else { return }
        productErrors[productID] = nil
        await loadCard(of: product)
    }

    /// Reads one product's prices for its card. A failure stays on its card
    /// (Apple's server failing offers Try Again); the selected product's
    /// prices take a read that worked after theirs failed.
    private func loadCard(of product: PricingProduct) async {
        do {
            let sheet = try await services.priceSheet(for: product, commission: strategy.commission)
            guard !Task.isCancelled else { return }
            productMatrices[product.id] = makeMatrix(product: product, sheet: sheet)
            productErrors[product.id] = nil
            unreadProductIDs.remove(product.id)
            recoverSelectedPrices(of: product, sheet: sheet)
        } catch let error as PricingSheetError {
            productErrors[product.id] = error.cardText
            unreadProductIDs.remove(product.id)
        } catch {
            guard !Task.isCancelled else { return }
            if PricingReadFailure.isProductFailure(error) {
                productErrors[product.id] = PricingReadFailure.text(productName: product.name)
                unreadProductIDs.insert(product.id)
            } else {
                productErrors[product.id] = AppleErrorCopy(
                    String(localized: "\(product.name)’s prices didn’t load.", comment: "kind:error"), error: error
                ).text
                unreadProductIDs.remove(product.id)
            }
        }
    }

    /// The queue changed: the cards read it again.
    func productsQueueDidChange() {
        for matrix in productMatrices.values { matrix.queueDidChange() }
    }

    // MARK: - Reading

    /// Each loaded product's card, in the catalog's order.
    var productCards: [PricingProductCard] {
        (catalog?.products ?? []).compactMap(card(for:))
    }

    func card(for product: PricingProduct) -> PricingProductCard? {
        guard let matrix = productMatrices[product.id] else { return nil }
        let isSettingStartingPrices = isSettingStartingPrices(of: product)
        var card = PricingProductCard.make(
            product: product,
            rows: matrix.rows,
            showsSuggestions: matrix.showsSuggestions && !isSettingStartingPrices,
            isDismissed: modes.isPriceSuggestionDismissed(productID: product.id, appID: app.id)
        )
        card.isSettingStartingPrices = isSettingStartingPrices
        if !isSettingStartingPrices, !modes.isPriceSuggestionDismissed(productID: product.id, appID: app.id) {
            card.isCheckingPrices = matrix.isCheckingGrid
            card.gridFailure = matrix.gridFailureCopy
        }
        return card
    }

    /// The product's starting prices are still waiting in Review & Push:
    /// its new subscription (or Set Starting Price) is being pushed, or
    /// stopped partway (`Prices · 14 of 175`). The countries it has a price
    /// in so far aren't its prices yet, so it suggests none until the push
    /// has set them all and Pricing reads them again.
    func isSettingStartingPrices(of product: PricingProduct) -> Bool {
        guard !product.isInAppPurchase else { return false }
        let ids = [
            NewSubscriptionChangeBuilder.changeID(appID: app.id, productID: product.productID),
            NewSubscriptionChangeBuilder.startingPriceChangeID(appID: app.id, productID: product.productID),
        ]
        return ids.contains { queue.change(id: $0) != nil }
    }

    /// Products with an open price suggestion: the Prices badge and Accept
    /// All n.
    var openPriceSuggestionCount: Int {
        productCards.count { $0.suggestion != nil }
    }

    /// "Price suggestions for 3 products. See each one below, or accept
    /// them together."
    var priceSuggestionsBannerText: String {
        let count = openPriceSuggestionCount
        return count == 1
            ? String(localized: "Price suggestions for 1 product. Review below or accept here.")
            : String(localized: "Price suggestions for \(count) products. Review below or accept all here.")
    }

    /// Countries and regions the app has prices in, for the header.
    var territoryCount: Int? {
        let count = productMatrices.values.first?.rows.count ?? matrix?.rows.count ?? 0
        return count > 0 ? count : nil
    }

    var hasDismissedPriceSuggestions: Bool {
        !(modes.dismissedPriceSuggestions[app.id]?.isEmpty ?? true)
    }

    // MARK: - Deciding

    /// A card's Accept: every territory gets the strategy's price as a
    /// pending change (hand edits stay). Undo puts the queue back.
    func acceptPriceSuggestion(productID: String) async {
        guard let product = catalog?.product(id: productID) else { return }
        let undo = await accept([product])
        guard let undo else { return }
        show(String(localized: "Accepted prices for \(product.name). In Review & Push."), undo: undo)
    }

    /// Accept All n.
    func acceptAllPriceSuggestions() async {
        let products = productCards.filter { $0.suggestion != nil }.map(\.product)
        guard !products.isEmpty, let undo = await accept(products) else { return }
        let text = products.count == 1
            ? String(localized: "Accepted prices for \(products[0].name). In Review & Push.")
            : String(localized: "Accepted prices for \(products.count) products, now in Review & Push.")
        show(text, undo: undo)
    }

    /// A card's Dismiss: the suggestion goes until Restore Dismissed.
    func dismissPriceSuggestion(productID: String) {
        modes.dismissPriceSuggestion(productID: productID, appID: app.id)
    }

    func restoreDismissedPriceSuggestions() {
        modes.restorePriceSuggestions(appID: app.id)
    }

    func undoToast() {
        toastUndo?()
        toastUndo = nil
        toast = nil
    }

    /// Follows the strategy for each product; returns how to undo it, or
    /// nil when nothing was written.
    private func accept(_ products: [PricingProduct]) async -> (() -> Void)? {
        let matrices = products.compactMap { productMatrices[$0.id] }.filter { !$0.isReadOnly }
        guard !matrices.isEmpty else { return nil }
        let prefixes = matrices.map { PriceChangeFactory.changeID(productID: $0.product.id, territoryID: "") }
        let owned: (PendingChange) -> Bool = { [app] change in
            change.appID == app.id && change.section == .subscriptionPricing && prefixes.contains { change.id.hasPrefix($0) }
        }
        let before = queue.changes(for: app.id, section: .subscriptionPricing).filter(owned)
        for matrix in matrices {
            followedProductIDs.insert(matrix.product.id)
            await matrix.follow()
        }
        matrix?.queueDidChange()
        let after = queue.changes(for: app.id, section: .subscriptionPricing).filter(owned)
        guard after != before else { return nil }
        return { [weak self] in
            guard let self else { return }
            queue.discardAll(where: owned)
            queue.upsert(contentsOf: before)
            for matrix in matrices {
                followedProductIDs.remove(matrix.product.id)
                matrix.stopFollowing()
            }
            productsQueueDidChange()
            matrix?.queueDidChange()
        }
    }

    private func show(_ text: String, undo: @escaping () -> Void) {
        toastUndo = undo
        toast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push"))
    }
}
