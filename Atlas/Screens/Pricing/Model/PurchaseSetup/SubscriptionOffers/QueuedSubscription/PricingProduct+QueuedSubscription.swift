//
//  PricingProduct+QueuedSubscription.swift
//  Atlas
//

import Foundation

extension PricingProduct {
    /// Whether it's a stand-in for a new subscription waiting in Review &
    /// Push (`PurchaseSetupTarget.offerSubscription`): App Store Connect
    /// has no offers for it yet.
    var isQueuedSubscription: Bool {
        QueuedSubscriptionPlaceholder(token: id) != nil
    }
}
