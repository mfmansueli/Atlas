//
//  PricingViewModel+PurchaseSetup.swift
//  Atlas
//

import Foundation

/// Create In-App Purchase, Add Introductory Offer… and Review Screenshot…:
/// each queues a change in Review & Push (or one more step of a new
/// product's change), which the push sends.
extension PricingViewModel {
    var setupQueue: PurchaseSetupQueue {
        PurchaseSetupQueue(app: app, queue: queue)
    }

    // MARK: - New in-app purchases

    /// New subscriptions and in-app purchases of this app waiting in Review & Push.
    var queuedNewProducts: [PendingChange] {
        queuedNewSubscriptions + NewInAppPurchaseChangeBuilder.queued(in: queue, appID: app.id)
    }

    /// What Create In-App Purchase starts with: a non-consumable "Bruma
    /// Lifetime" under the bundle ID, in the app's primary language.
    func newInAppPurchaseDefaults() -> NewInAppPurchase {
        let name = String(localized: "\(NewSubscription.shortName(of: app.name)) Lifetime")
        let locale = app.primaryLocale.flatMap(StoreLocaleCatalog.locale(code:)) ?? .englishUS
        return NewInAppPurchase(
            referenceName: name,
            productID: "\(app.bundleID).lifetime",
            locale: locale,
            displayName: name,
            description: ""
        )
    }

    /// What App Store Connect would refuse, given the app's products and
    /// the new ones in Review & Push.
    func problems(for purchase: NewInAppPurchase) -> [NewSubscriptionProblem] {
        let ownID = NewInAppPurchaseChangeBuilder.changeID(appID: app.id, productID: NewSubscription.trimmed(purchase.productID))
        let taken = NewSubscriptionChangeBuilder.takenProductIDs(appID: app.id, catalog: catalog, queue: queue, except: ownID)
        return purchase.problems(takenProductIDs: taken)
    }

    /// Create In-App Purchase's Add to Review & Push.
    func queueNewInAppPurchase(_ purchase: NewInAppPurchase) {
        let change = NewInAppPurchaseChangeBuilder(app: app).change(for: purchase, problems: problems(for: purchase), at: today())
        queue.upsert(PurchaseSetupQueue.carryingExtras(from: queue.change(id: change.id), into: change))
        setup.isNewInAppPurchaseSheetPresented = false
    }

    // MARK: - Introductory offers

    /// Whether Add Introductory Offer… shows for `product`: a subscription
    /// with none in App Store Connect (as far as Atlas read) and none waiting.
    func canAddIntroductoryOffer(to product: PricingProduct) -> Bool {
        guard !product.isInAppPurchase else { return false }
        let target = PurchaseSetupTarget.existing(product)
        return setupQueue.queuedIntroductoryOffer(for: target) == nil && setup.extras[product.id]?.introductorySummary == nil
    }

    func openIntroductoryOffer(for product: PricingProduct) {
        setup.introductoryOfferTarget = .existing(product)
    }

    /// Add Introductory Offer… on a new subscription waiting in Review & Push.
    func openIntroductoryOffer(forQueued change: PendingChange) {
        setup.introductoryOfferTarget = PurchaseSetupTarget.queued(change)
    }

    /// What App Store Connect would refuse for `target`, counting the offer
    /// it already has.
    func problems(for offer: NewIntroductoryOffer, target: PurchaseSetupTarget) -> [IntroductoryOfferProblem] {
        let existing: String? = if case let .existing(product) = target.place { setup.extras[product.id]?.introductorySummary } else { nil }
        return offer.problems(period: target.period ?? .oneMonth, subscriptionPrice: target.usPrice, existing: existing, today: today())
    }

    /// Add Introductory Offer…'s Add to Review & Push.
    func queueIntroductoryOffer(_ offer: NewIntroductoryOffer, for target: PurchaseSetupTarget) {
        setupQueue.queueIntroductoryOffer(offer, for: target, problems: problems(for: offer, target: target), source: .you, at: today())
        setup.introductoryOfferTarget = nil
    }

    /// The selected subscription's introductory offers in App Store
    /// Connect, as the Offers tab lists them.
    func readIntroductoryOffers(for product: PricingProduct) async -> [SubscriptionOffer] {
        await setup.load([product])
        let terms = setup.extras[product.id]?.introductoryTerms ?? []
        return terms.enumerated().map { ExistingIntroductoryOffer.subscriptionOffer($1, index: $0, subscriptionPrice: product.basePrice) }
    }

    // MARK: - Review screenshots

    func openReviewScreenshot(for product: PricingProduct) {
        setup.reviewScreenshotTarget = .existing(product)
    }

    /// Review Screenshot… on a new product waiting in Review & Push.
    func openReviewScreenshot(forQueued change: PendingChange) {
        setup.reviewScreenshotTarget = PurchaseSetupTarget.queued(change)
    }

    /// The product's screenshot in App Store Connect, once read.
    func reviewScreenshotState(of product: PricingProduct) -> PurchaseReviewScreenshotState? {
        setup.extras[product.id]?.reviewScreenshot
    }

    /// Whether a screenshot for `product` waits in Review & Push.
    func hasQueuedReviewScreenshot(for product: PricingProduct) -> Bool {
        setupQueue.queuedReviewScreenshot(for: .existing(product)) != nil
    }

    /// Review Screenshot…'s Add to Review & Push.
    func queueReviewScreenshot(_ file: PurchaseReviewScreenshotFile, for target: PurchaseSetupTarget) {
        var current: PurchaseReviewScreenshotState?
        if case let .existing(product) = target.place { current = setup.extras[product.id]?.reviewScreenshot }
        setupQueue.queueReviewScreenshot(file, for: target, current: current, source: .you, at: today())
        setup.reviewScreenshotTarget = nil
    }

    /// Reads every product's offers and screenshot, for the cards.
    func loadPurchaseExtras() async {
        await setup.load(catalog?.products ?? [])
    }
}
