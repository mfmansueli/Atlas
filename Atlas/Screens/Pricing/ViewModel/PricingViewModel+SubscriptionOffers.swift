//
//  PricingViewModel+SubscriptionOffers.swift
//  Atlas
//

import Foundation

/// New Promotional Offer…, New Win-Back Offer…, New Offer Code… and what
/// the Offers tab does with an offer App Store Connect has (change a
/// promotional offer's prices, a win-back offer's settings, add codes,
/// delete or deactivate): each queues a change in Review & Push, checked
/// like the assistants' proposals (`SubscriptionOfferQueue`).
extension PricingViewModel {
    var offerQueue: SubscriptionOfferQueue {
        SubscriptionOfferQueue(app: app, queue: queue, today: today())
    }

    /// What Atlas read of `product`'s offers in App Store Connect.
    func offerExtras(for product: PricingProduct) -> PurchaseExtras {
        setup.extras[product.id] ?? PurchaseExtras()
    }

    /// Whether the new offer menu works for `product`: a subscription App
    /// Store Connect has, whose offers Atlas could read (so it knows the
    /// identifiers already taken), or a new one waiting in Review & Push,
    /// which has none yet.
    func canAddOffers(to product: PricingProduct) -> Bool {
        !product.isInAppPurchase && (product.isQueuedSubscription || setup.extras[product.id]?.offersRead == true)
    }

    /// The subscription a new one waiting in Review & Push takes offers
    /// through (`PurchaseSetupTarget.offerSubscription`); nil for another change.
    func offerSubscription(forQueued change: PendingChange) -> PricingProduct? {
        guard NewSubscriptionChangeBuilder.owns(change) else { return nil }
        return PurchaseSetupTarget.queued(change)?.offerSubscription
    }

    /// The offers waiting with a new subscription, pushed after it and
    /// discarded with it.
    func waitingOffers(forQueued change: PendingChange) -> [PendingChange] {
        SubscriptionOfferChanges.waiting(for: change, in: queue)
    }

    // MARK: - Listing

    /// The offers Atlas read for `product`, as the Offers tab lists them.
    func existingSubscriptionOffers(for product: PricingProduct) -> [SubscriptionOffer] {
        let extras = offerExtras(for: product)
        let price = product.basePrice
        return extras.promotionalOffers.map { $0.subscriptionOffer(subscriptionPrice: price) }
            + extras.winBackOffers.map { $0.subscriptionOffer(subscriptionPrice: price) }
            + extras.offerCodes.map { $0.subscriptionOffer(subscriptionPrice: price) }
    }

    /// The selected subscription's offer changes waiting in Review & Push.
    var queuedSubscriptionOffers: [PendingChange] {
        guard let product = selectedProduct, !product.isInAppPurchase else { return [] }
        return offerQueue.queued(for: product)
    }

    /// The promotional offer the Offers tab has selected, if it's one App
    /// Store Connect has.
    func promotionalOffer(id: SubscriptionOffer.ID?, of product: PricingProduct) -> ExistingPromotionalOffer? {
        offerExtras(for: product).promotionalOffers.first { ExistingPromotionalOffer.offerID($0.id) == id }
    }

    func winBackOffer(id: SubscriptionOffer.ID?, of product: PricingProduct) -> ExistingWinBackOffer? {
        offerExtras(for: product).winBackOffers.first { ExistingWinBackOffer.offerID($0.id) == id }
    }

    func offerCode(id: SubscriptionOffer.ID?, of product: PricingProduct) -> ExistingOfferCode? {
        offerExtras(for: product).offerCodes.first { ExistingOfferCode.offerID($0.id) == id }
    }

    /// Whether a change for this offer already waits in Review & Push
    /// (its actions then say so instead of queuing another).
    func hasQueuedChange(_ id: PendingChange.ID) -> Bool {
        queue.change(id: id) != nil
    }

    // MARK: - Opening

    func open(_ route: SubscriptionOfferRoute) {
        setup.offerRoute = route
    }

    func closeOfferSheet() {
        setup.offerRoute = nil
    }

    // MARK: - Promotional offers

    func problems(for offer: NewPromotionalOffer, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        offerQueue.problems(for: offer, subscription: subscription, extras: offerExtras(for: subscription))
    }

    func queuePromotionalOffer(_ offer: NewPromotionalOffer, for subscription: PricingProduct) {
        offerQueue.queue(offer, for: subscription, extras: offerExtras(for: subscription), source: .you)
        closeOfferSheet()
    }

    func problems(forPrices terms: OfferTerms, of offer: ExistingPromotionalOffer, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        offerQueue.problems(forPrices: terms, of: offer, subscription: subscription)
    }

    func queuePromotionalPrices(_ terms: OfferTerms, for offer: ExistingPromotionalOffer, subscription: PricingProduct) {
        offerQueue.queuePrices(terms, for: offer, subscription: subscription, source: .you)
        closeOfferSheet()
    }

    func deletePromotionalOffer(_ offer: ExistingPromotionalOffer, of subscription: PricingProduct) {
        offerQueue.queueDeletion(of: offer, subscription: subscription, source: .you)
    }

    // MARK: - Win-back offers

    func problems(for offer: NewWinBackOffer, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        offerQueue.problems(for: offer, subscription: subscription, extras: offerExtras(for: subscription))
    }

    func queueWinBackOffer(_ offer: NewWinBackOffer, for subscription: PricingProduct) {
        offerQueue.queue(offer, for: subscription, extras: offerExtras(for: subscription), source: .you)
        closeOfferSheet()
    }

    func problems(forSettings settings: WinBackOfferSettings, of offer: ExistingWinBackOffer) -> [SubscriptionOfferProblem] {
        offerQueue.problems(forSettings: settings, of: offer)
    }

    func queueWinBackSettings(_ settings: WinBackOfferSettings, for offer: ExistingWinBackOffer, subscription: PricingProduct) {
        offerQueue.queueSettings(settings, for: offer, subscription: subscription, source: .you)
        closeOfferSheet()
    }

    func deleteWinBackOffer(_ offer: ExistingWinBackOffer, of subscription: PricingProduct) {
        offerQueue.queueDeletion(of: offer, subscription: subscription, source: .you)
    }

    // MARK: - Offer codes

    func problems(for code: NewOfferCode, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        offerQueue.problems(for: code, subscription: subscription, extras: offerExtras(for: subscription))
    }

    func queueOfferCode(_ code: NewOfferCode, for subscription: PricingProduct) {
        offerQueue.queue(code, for: subscription, extras: offerExtras(for: subscription), source: .you)
        closeOfferSheet()
    }

    func problems(for custom: NewCustomCode, code: ExistingOfferCode, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        offerQueue.problems(for: custom, code: code, subscription: subscription, extras: offerExtras(for: subscription))
    }

    func queueCustomCode(_ custom: NewCustomCode, for code: ExistingOfferCode, subscription: PricingProduct) {
        offerQueue.queue(custom, for: code, subscription: subscription, extras: offerExtras(for: subscription), source: .you)
        closeOfferSheet()
    }

    func problems(for batch: NewOneTimeCodes, code: ExistingOfferCode) -> [SubscriptionOfferProblem] {
        offerQueue.problems(for: batch, code: code)
    }

    func queueOneTimeCodes(_ batch: NewOneTimeCodes, for code: ExistingOfferCode, subscription: PricingProduct) {
        offerQueue.queue(batch, for: code, subscription: subscription, source: .you)
        closeOfferSheet()
    }

    func deactivate(_ target: OfferCodeChangeBuilder.Target, in code: ExistingOfferCode, of subscription: PricingProduct) {
        offerQueue.queueDeactivation(of: target, in: code, subscription: subscription, source: .you)
    }

    // MARK: - One-time codes' values

    /// Save Codes…: reads the batch's CSV, then opens the save panel.
    func saveCodes(_ batch: ExistingOneTimeCodes, of code: ExistingOfferCode) async {
        setup.codesSaveError = nil
        guard let reader = setup.codeValues ?? (setup.transport() as? any OneTimeCodeValuesReading) else {
            setup.codesSaveError = String(localized: "Connect App Store Connect to read the codes.")
            return
        }
        do {
            let data = try await reader.oneTimeCodeValues(batchID: batch.id)
            setup.codesFile = OneTimeCodesFile(data: data, fileName: batch.fileName(offerName: code.name))
        } catch {
            setup.codesSaveError = String(localized: "Apple hasn’t sent the codes yet. Try again later. \(error.localizedDescription)")
        }
    }
}
