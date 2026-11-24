//
//  PricingViewModel+ReviewLater.swift
//  Atlas
//

import Foundation

/// A new subscription added with "Use Apple’s prices now, review the
/// recommendations later" (README — Assist §5): once it's pushed and its
/// prices are read, a banner names it with Review…, whose sheet lists the
/// countries where the recommended price differs, to apply all, some, or
/// keep Apple's prices.
extension PricingViewModel {
    /// Subscriptions waiting for that review, with recommendations open.
    var reviewLaterProducts: [PricingProduct] {
        (catalog?.products ?? []).filter { product in
            !product.isInAppPurchase
                && modes.isReviewingLater(productID: product.productID, appID: app.id)
                && !reviewLaterPlaces(productID: product.id).isEmpty
        }
    }

    /// The countries and regions whose recommended price differs from
    /// what it has, with nothing queued for them yet.
    func reviewLaterPlaces(productID: String) -> [NewSubscriptionRecommendation.Place] {
        guard let matrix = productMatrices[productID], !isSettingStartingPrices(of: matrix.product) else { return [] }
        return matrix.rows.filter { !$0.isBase && $0.hasSuggestion && $0.queued == nil }.map { row in
            NewSubscriptionRecommendation.Place(territory: row.territory, equalized: row.current.customerPrice, recommended: row.target.customerPrice)
        }
    }

    /// "Recommended prices wait for Lumen Plus Weekly".
    func reviewLaterTitle(_ product: PricingProduct) -> String {
        String(localized: "Recommended prices wait for \(product.name)", comment: "kind:banner")
    }

    /// "112 countries and regions could pay less. Apple’s prices are live meanwhile."
    func reviewLaterDetail(_ product: PricingProduct) -> String {
        let places = reviewLaterPlaces(productID: product.id)
        let lower = places.count(where: \.isLower)
        return lower == places.count
            ? String(localized: "\(lower) countries and regions could pay less. Apple’s prices are live meanwhile.", comment: "kind:banner")
            : String(localized: "\(places.count) countries and regions have a recommended price. Apple’s prices are live meanwhile.", comment: "kind:banner")
    }

    /// Apply Selected or Apply All: those countries' recommended prices go
    /// to Review & Push, and the review is done.
    func applyRecommendations(productID: String, territoryIDs: [String]) async {
        guard let matrix = productMatrices[productID], !territoryIDs.isEmpty else { return }
        await matrix.applySuggestion(to: territoryIDs)
        modes.setReviewLater(false, productID: matrix.product.productID, appID: app.id)
        reviewLaterProductID = nil
        productsQueueDidChange()
        self.matrix?.queueDidChange()
        let text = territoryIDs.count == 1
            ? String(localized: "Recommended price for 1 country, now in Review & Push.", comment: "kind:toast")
            : String(localized: "Recommended prices for \(territoryIDs.count) countries, now in Review & Push.", comment: "kind:toast")
        toast = ToastMessage(text: text, actionTitle: String(localized: "Review & Push"))
    }

    /// Keep Apple's Prices: the review is done and its suggestion goes,
    /// until Restore Dismissed.
    func keepApplePrices(productID: String) {
        guard let product = catalog?.product(id: productID) else { return }
        modes.setReviewLater(false, productID: product.productID, appID: app.id)
        dismissPriceSuggestion(productID: productID)
        reviewLaterProductID = nil
    }
}
