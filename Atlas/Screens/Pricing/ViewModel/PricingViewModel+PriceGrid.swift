//
//  PricingViewModel+PriceGrid.swift
//  Atlas
//

import Foundation

// Apple's real price points before any suggestion (Phase 1): each
// product's ladders are read once its prices show, one product at a time
// (the open one first), from the cache when it has them. On screen they're
// always read; read ahead off screen, only while the hourly quota leaves
// room (`gridReadAhead`). A push that changed a product's prices drops
// the ladders read before it.
extension PricingViewModel {
    /// Reads Apple's price points for every product that suggests prices
    /// and doesn't have them yet: the open product first, then the cards'
    /// order. Read ahead, it stops once the quota runs low.
    func loadGrids() async {
        guard let catalog else { return }
        var products = catalog.products
        if let openID = productRoute?.productID ?? selectedProductID, let index = products.firstIndex(where: { $0.id == openID }) {
            products.insert(products.remove(at: index), at: 0)
        }
        for product in products {
            guard !Task.isCancelled else { return }
            let matrices = gridMatrices(productID: product.id)
            guard matrices.contains(where: \.needsGrid) else { continue }
            if let gridReadAhead, !gridReadAhead.allowsRead { return }
            for matrix in matrices where matrix.needsGrid {
                await matrix.loadGrid()
            }
        }
    }

    /// The product's page opened: its points are read now, whatever the
    /// quota (the person is looking).
    func loadPageGrid(productID: PricingProduct.ID) async {
        for matrix in gridMatrices(productID: productID) where matrix.needsGrid {
            await matrix.loadGrid()
        }
    }

    /// Try Again after the points didn't load.
    func retryGrid(productID: PricingProduct.ID) async {
        await loadPageGrid(productID: productID)
    }

    /// The product's points, while its suggestions would show: checking,
    /// failed or ready; nil for in-app purchases, Keep my prices and a
    /// product whose prices aren't read yet.
    func countriesGrid(productID: PricingProduct.ID) -> PriceGridState? {
        guard let matrix = countriesMatrix(productID: productID), matrix.showsSuggestions,
              !modes.isPriceSuggestionDismissed(productID: productID, appID: app.id)
        else { return nil }
        return matrix.grid
    }

    /// Drops the ladders read before a push that changed a product's
    /// prices, for pushes recent enough that a ladder from before them
    /// could still be kept (`LivePricingCache.maxAge`).
    func forgetPushedLadders() async {
        let oldest = today().addingTimeInterval(-LivePricingCache.maxAge)
        for record in pushRecords() where record.changedPrices && record.date > oldest {
            for productID in Self.pricedProductIDs(in: record.pushed) {
                await services.forgetLadders(for: productID, fetchedBefore: record.date)
            }
        }
    }

    /// The products whose prices these changes set: a subscription's
    /// `price.<product>.<territory>`, an in-app purchase's
    /// `iapPrice.<product>`.
    static func pricedProductIDs(in changes: [PendingChange]) -> Set<String> {
        // "price.": a change ID without its product and territory.
        let subscription = PriceChangeFactory.changeID(productID: "", territoryID: "").dropLast()
        var result = Set<String>()
        for change in changes where change.section == .subscriptionPricing {
            if change.id.hasPrefix(InAppPurchaseCountryPrices.idPrefix) {
                result.insert(String(change.id.dropFirst(InAppPurchaseCountryPrices.idPrefix.count)))
            } else if change.id.hasPrefix(subscription) {
                let rest = change.id.dropFirst(subscription.count)
                if let dot = rest.lastIndex(of: ".") { result.insert(String(rest[..<dot])) }
            }
        }
        return result
    }

    /// The product's matrices: its card's and, when it's selected, the
    /// selected one (both read through the same cache).
    private func gridMatrices(productID: PricingProduct.ID) -> [PriceMatrixModel] {
        var result: [PriceMatrixModel] = []
        if let card = productMatrices[productID] { result.append(card) }
        if let matrix, matrix.product.id == productID, !result.contains(where: { $0 === matrix }) { result.append(matrix) }
        return result
    }
}
