//
//  PricingViewModel+Actions.swift
//  Atlas
//

import Foundation

/// Workspace intents meant for Pricing: each opens the product cards or a
/// product's page (board 73) on the right tab.
extension PricingViewModel {
    /// Handles an intent meant for Pricing. Returns whether it did, so the
    /// caller consumes it.
    func handle(_ intent: WorkspaceIntent) async -> Bool {
        switch intent {
        case .reviewSuggestions:
            // The cards, where each product's suggestion is.
            if mode == .keepPrices { apply(mode: .showSuggestions) }
            page = .prices
            closeProduct()
            return true
        case .applyRecommendedPrices:
            if mode == .keepPrices { apply(mode: .showSuggestions) }
            openIntentProduct(tab: .pricesByCountry)
            await applyRecommendedPrices()
            return true
        case .showResults:
            openIntentProduct(tab: .results)
            return true
        case let .showPrices(shown):
            openIntentProduct(tab: .pricesByCountry)
            pricesByCountry.display = shown
            return true
        case let .editPriceSchedule(productID):
            // Review passes the price group's ID, which is the subscription's.
            let id = productID.flatMap { catalog?.product(id: $0)?.id }
            openIntentProduct(id, tab: .pricesByCountry)
            if let id { await select(productID: id) }
            // Review & Push's sheet is still closing; macOS shows one sheet at a time.
            try? await Task.sleep(for: .milliseconds(400))
            if (matrix?.pendingCount ?? 0) > 0 { openSchedule() }
            return true
        case .pageAction:
            startPageAction()
            return true
        default:
            return handleFromAnalytics(intent)
        }
    }

    /// Where an Analytics finding sends the person: the product cards with
    /// "Preview in" on one territory (`price-br`), or the Retention page.
    private func handleFromAnalytics(_ intent: WorkspaceIntent) -> Bool {
        switch intent {
        case let .showTerritoryPrice(alpha2):
            showTerritoryPreview(alpha2: alpha2)
            return true
        case .showRetention:
            page = .retention
            return true
        case .autopilot(.makeReviewScreenshots):
            // The cards, where each product's screenshot shows.
            page = .prices
            closeProduct()
            makeReviewScreenshots()
            return true
        default:
            return false
        }
    }

    /// The product cards with "Preview in" on `alpha2`'s country: what
    /// each product costs there, and ‹ › to the other countries with a
    /// change (board 73).
    func showTerritoryPreview(alpha2: String) {
        page = .prices
        closeProduct()
        if let territory = TerritoryCatalog.standard.territory(alpha2: alpha2) { previewTerritoryID = territory.id }
    }

    /// The page of `productID`, else the open product's, else the selected
    /// or the catalog's first, on `tab`.
    private func openIntentProduct(_ productID: PricingProduct.ID? = nil, tab: PricingProductTab) {
        page = .prices
        guard let id = productID ?? productRoute?.productID ?? selectedProductID ?? catalog?.defaultProduct?.id else { return }
        if productRoute?.productID == id {
            productRoute?.tab = tab
        } else {
            openProduct(id, tab: tab)
        }
    }
}
