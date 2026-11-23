//
//  PurchaseSetupTarget+Offers.swift
//  Atlas
//

import Foundation

extension PurchaseSetupTarget {
    /// The subscription a promotional offer, win-back offer or offer code
    /// is built for: the one App Store Connect has, or, for a new one
    /// waiting in Review & Push, a stand-in whose id is its placeholder
    /// (`QueuedSubscriptionPlaceholder`), with its name, period and US
    /// starting price. Nil for an in-app purchase.
    var offerSubscription: PricingProduct? {
        guard isSubscription else { return nil }
        switch place {
        case let .existing(product):
            return product
        case .queued:
            return PricingProduct(
                id: QueuedSubscriptionPlaceholder(productID: productID).token,
                name: name,
                productID: productID,
                period: period,
                isInAppPurchase: false,
                reviewState: String(localized: "Waiting in Review & Push"),
                basePrice: usPrice
            )
        }
    }
}
