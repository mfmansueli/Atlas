//
//  PurchaseSetupTarget.swift
//  Atlas
//

import Foundation

/// The product an introductory offer or App Review screenshot is for: one
/// App Store Connect has, or a new subscription or in-app purchase waiting
/// in Review & Push, whose change then carries it as one more step.
struct PurchaseSetupTarget: Identifiable, Hashable, Sendable {
    enum Place: Hashable, Sendable {
        case existing(PricingProduct)
        /// The queued change that creates it.
        case queued(PendingChange.ID)
    }

    var productID: String
    var name: String
    var owner: PurchaseReviewScreenshotOwner
    /// A subscription's billing period.
    var period: SubscriptionPeriod?
    /// Its price in the United States, when it has or will have one.
    var usPrice: Decimal?
    var place: Place

    var id: String { productID }

    var isQueued: Bool {
        if case .queued = place { return true }
        return false
    }

    var isSubscription: Bool { owner == .subscription }

    static func existing(_ product: PricingProduct) -> PurchaseSetupTarget {
        PurchaseSetupTarget(
            productID: product.productID,
            name: product.name,
            owner: product.isInAppPurchase ? .inAppPurchase : .subscription,
            period: product.period,
            usPrice: product.basePrice,
            place: .existing(product)
        )
    }

    /// A queued new subscription's or in-app purchase's change as a target;
    /// nil for any other change.
    static func queued(_ change: PendingChange) -> PurchaseSetupTarget? {
        if NewSubscriptionChangeBuilder.owns(change), let productID = NewSubscriptionChangeBuilder.productID(of: change) {
            let create = change.requests.first.flatMap { PushPagedRead.body(of: $0)?["data"] as? [String: Any] }
            let period = ((create?["attributes"] as? [String: Any])?["subscriptionPeriod"] as? String).flatMap(SubscriptionPeriod.init(rawValue:))
            return PurchaseSetupTarget(
                productID: productID, name: change.title, owner: .subscription, period: period,
                usPrice: change.requests.lazy.compactMap(SubscriptionStartingPrices.init).first?.customerPrice,
                place: .queued(change.id)
            )
        }
        if NewInAppPurchaseChangeBuilder.owns(change), let productID = NewInAppPurchaseChangeBuilder.productID(of: change) {
            return PurchaseSetupTarget(
                productID: productID, name: change.title, owner: .inAppPurchase, period: nil,
                usPrice: change.requests.lazy.compactMap(InAppPurchaseStartingPrice.init).first?.customerPrice,
                place: .queued(change.id)
            )
        }
        return nil
    }

    /// The product an assistant or a sheet means: by product ID, App Store
    /// Connect ID or name (case ignored), among the app's products, then the
    /// new ones in Review & Push.
    @MainActor
    static func find(_ identifier: String, appID: StoreApp.ID, catalog: PricingCatalog?, queue: ChangeQueue) -> PurchaseSetupTarget? {
        let wanted = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let product = catalog?.products.first(where: { [$0.id, $0.productID, $0.name].contains { $0.lowercased() == wanted } }) {
            return existing(product)
        }
        let queued = NewSubscriptionChangeBuilder.queued(in: queue, appID: appID) + NewInAppPurchaseChangeBuilder.queued(in: queue, appID: appID)
        return queued.lazy.compactMap(Self.queued).first { $0.productID.lowercased() == wanted || $0.name.lowercased() == wanted }
    }
}
