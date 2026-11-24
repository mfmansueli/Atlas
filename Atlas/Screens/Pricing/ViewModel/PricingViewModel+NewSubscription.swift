//
//  PricingViewModel+NewSubscription.swift
//  Atlas
//

import Foundation

/// Create Subscription and Set Starting Price: both queue a change in
/// Review & Push, which creates the subscription or sets its first prices
/// when the person pushes.
extension PricingViewModel {
    var newSubscriptionBuilder: NewSubscriptionChangeBuilder {
        NewSubscriptionChangeBuilder(app: app)
    }

    /// New subscriptions of this app waiting in Review & Push.
    var queuedNewSubscriptions: [PendingChange] {
        NewSubscriptionChangeBuilder.queued(in: queue, appID: app.id)
    }

    /// The app's subscription groups, for the group picker.
    var subscriptionGroups: [PricingProductGroup] {
        catalog?.groups.filter { !$0.isInAppPurchases } ?? []
    }

    /// What Create Subscription starts with: the app's first group, or a
    /// new "Bruma Premium"; a monthly subscription named after it, with a
    /// product ID under the bundle ID.
    func newSubscriptionDefaults() -> NewSubscription {
        let short = NewSubscription.shortName(of: app.name)
        let groupName = String(localized: "\(short) Premium")
        let group = subscriptionGroups.first.map { NewSubscriptionGroup.existing(id: $0.id, referenceName: $0.name) }
            ?? .new(referenceName: groupName, displayName: groupName)
        let period = SubscriptionPeriod.oneMonth
        let locale = app.primaryLocale.flatMap(StoreLocaleCatalog.locale(code:)) ?? .englishUS
        return NewSubscription(
            group: group,
            referenceName: "\(group.referenceName) \(period.shortTitle)",
            productID: Self.suggestedProductID(bundleID: app.bundleID, period: period),
            period: period,
            locale: locale,
            displayName: "\(group.referenceName) \(period.shortTitle)",
            description: ""
        )
    }

    /// `com.lima.bruma.premium.monthly`.
    static func suggestedProductID(bundleID: String, period: SubscriptionPeriod) -> String {
        "\(bundleID).premium.\(NewSubscription.productIDSuffix(for: period))"
    }

    /// What App Store Connect would refuse, given the app's products and
    /// the other new subscriptions in Review & Push.
    func problems(for subscription: NewSubscription) -> [NewSubscriptionProblem] {
        let ownID = NewSubscriptionChangeBuilder.changeID(appID: app.id, productID: NewSubscription.trimmed(subscription.productID))
        let taken = NewSubscriptionChangeBuilder.takenProductIDs(appID: app.id, catalog: catalog, queue: queue, except: ownID)
        return subscription.problems(takenProductIDs: taken, groupNames: subscriptionGroups.map(\.name))
    }

    /// Create Subscription's Add to Review & Push. With the recommended
    /// prices, they're worked out for its US price now; with Review Later,
    /// Pricing remembers to offer them once it's pushed.
    func queueNewSubscription(_ subscription: NewSubscription) {
        var subscription = subscription
        if subscription.priceChoice == .recommended, let price = subscription.price {
            subscription.recommendedPrices = recommendation(forPrice: price)?.prices ?? [:]
        }
        let change = newSubscriptionBuilder.change(for: subscription, problems: problems(for: subscription), at: today())
        queue.upsert(PurchaseSetupQueue.carryingExtras(from: queue.change(id: change.id), into: change))
        modes.setReviewLater(
            subscription.priceChoice == .reviewLater, productID: NewSubscription.trimmed(subscription.productID), appID: app.id
        )
        isNewSubscriptionSheetPresented = false
    }

    /// The recommended prices a new subscription at `price` would get, with
    /// the strategy Pricing uses and Apple's ratios from one of the app's
    /// subscriptions when their prices are read.
    func recommendation(forPrice price: Decimal) -> NewSubscriptionRecommendation? {
        let reference = productMatrices.values.first { !$0.product.isInAppPurchase }?.sheet ?? matrix?.sheet
        return NewSubscriptionRecommendation.make(
            basePrice: price, reference: reference, calculator: strategy.calculator, strategy: strategy.strategy
        )
    }

    func discardNewSubscription(id: PendingChange.ID) {
        queue.discard(id: id)
    }

    /// Set Starting Price's change for the selected subscription, if one is
    /// waiting.
    var queuedStartingPrice: PendingChange? {
        guard let product = selectedProduct else { return nil }
        return queue.change(id: NewSubscriptionChangeBuilder.startingPriceChangeID(appID: app.id, productID: product.productID))
    }

    /// Set Starting Price's Add to Review & Push.
    func queueStartingPrice(_ price: Decimal) {
        guard let product = selectedProduct else { return }
        queue.upsert(newSubscriptionBuilder.startingPriceChange(for: product, price: price, at: today()))
        isStartingPriceSheetPresented = false
    }
}
