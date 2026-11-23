//
//  SubscriptionOfferQueue.swift
//  Atlas
//

import Foundation

/// Checks and queues promotional offers, win-back offers and offer codes
/// the same way from Pricing's sheets and the assistants' tools: what App
/// Store Connect has for the subscription (`PurchaseExtras`) and what waits
/// in Review & Push decide what's refused, and each becomes its own change.
@MainActor
struct SubscriptionOfferQueue {
    let app: StoreApp
    let queue: ChangeQueue
    var today: Date = .now

    // MARK: - Promotional offers

    func problems(for offer: NewPromotionalOffer, subscription: PricingProduct, extras: PurchaseExtras) -> [SubscriptionOfferProblem] {
        let own = PromotionalOfferChangeBuilder.changeID(appID: app.id, productID: subscription.productID, identifier: offer.trimmedIdentifier)
        let taken = Set(queuedCreates(for: subscription, except: own).compactMap { PromotionalOfferChangeBuilder.offer(in: $0)?.trimmedIdentifier })
        return offer.problems(
            period: subscription.period ?? .oneMonth, subscriptionPrice: subscription.basePrice,
            existing: extras.promotionalOffers, takenIdentifiers: taken
        )
    }

    /// New prices for an offer App Store Connect has.
    func problems(forPrices terms: OfferTerms, of existing: ExistingPromotionalOffer, subscription: PricingProduct) -> [SubscriptionOfferProblem] {
        var problems = terms.problems(period: subscription.period ?? .oneMonth, subscriptionPrice: subscription.basePrice)
        if terms == existing.terms { problems.insert(.nothingChanged, at: 0) }
        return problems
    }

    @discardableResult
    func queue(
        _ offer: NewPromotionalOffer, for subscription: PricingProduct, extras: PurchaseExtras,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = PromotionalOfferChangeBuilder(app: app).change(
            for: offer, subscription: subscription, problems: problems(for: offer, subscription: subscription, extras: extras),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queuePrices(
        _ terms: OfferTerms, for existing: ExistingPromotionalOffer, subscription: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = PromotionalOfferChangeBuilder(app: app).pricesChange(
            for: existing, terms: terms, subscription: subscription,
            problems: problems(forPrices: terms, of: existing, subscription: subscription), source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queueDeletion(of existing: ExistingPromotionalOffer, subscription: PricingProduct, source: ChangeSource, evidence: [String] = []) -> PendingChange {
        let change = PromotionalOfferChangeBuilder(app: app).deletion(of: existing, subscription: subscription, source: source, evidence: evidence, at: today)
        queue.upsert(change)
        return change
    }

    // MARK: - Win-back offers

    func problems(for offer: NewWinBackOffer, subscription: PricingProduct, extras: PurchaseExtras) -> [SubscriptionOfferProblem] {
        let own = WinBackOfferChangeBuilder.changeID(appID: app.id, productID: subscription.productID, offerID: offer.trimmedOfferID)
        let taken = Set(queuedCreates(for: subscription, except: own).compactMap { WinBackOfferChangeBuilder.offer(in: $0)?.trimmedOfferID })
        return offer.problems(
            period: subscription.period ?? .oneMonth, subscriptionPrice: subscription.basePrice,
            existing: extras.winBackOffers, takenOfferIDs: taken, today: today
        )
    }

    func problems(forSettings settings: WinBackOfferSettings, of existing: ExistingWinBackOffer) -> [SubscriptionOfferProblem] {
        let started = existing.hasStarted(today: today)
        var problems = settings.problems(today: today, startIsFixed: started)
        if WinBackOfferChangeBuilder.changedKeys(from: existing.settings, to: settings, startIsFixed: started).isEmpty {
            problems.insert(.nothingChanged, at: 0)
        }
        return problems
    }

    @discardableResult
    func queue(
        _ offer: NewWinBackOffer, for subscription: PricingProduct, extras: PurchaseExtras,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = WinBackOfferChangeBuilder(app: app).change(
            for: offer, subscription: subscription, problems: problems(for: offer, subscription: subscription, extras: extras),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queueSettings(
        _ settings: WinBackOfferSettings, for existing: ExistingWinBackOffer, subscription: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = WinBackOfferChangeBuilder(app: app).settingsChange(
            for: existing, settings: settings, subscription: subscription,
            problems: problems(forSettings: settings, of: existing).filter { $0 != .nothingChanged },
            source: source, evidence: evidence, today: today, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queueDeletion(of existing: ExistingWinBackOffer, subscription: PricingProduct, source: ChangeSource, evidence: [String] = []) -> PendingChange {
        let change = WinBackOfferChangeBuilder(app: app).deletion(of: existing, subscription: subscription, source: source, evidence: evidence, at: today)
        queue.upsert(change)
        return change
    }

    // MARK: - Offer codes

    func problems(for code: NewOfferCode, subscription: PricingProduct, extras: PurchaseExtras) -> [SubscriptionOfferProblem] {
        let own = OfferCodeChangeBuilder.changeID(appID: app.id, productID: subscription.productID, name: code.trimmedName)
        let queued = queuedCreates(for: subscription, except: own)
        return code.problems(
            period: subscription.period ?? .oneMonth, subscriptionPrice: subscription.basePrice, existing: extras.offerCodes,
            takenNames: Set(queued.compactMap { OfferCodeChangeBuilder.offerCode(in: $0)?.trimmedName }),
            takenCustomCodes: queuedCustomCodes(for: subscription, except: own), today: today
        )
    }

    func problems(for custom: NewCustomCode, code: ExistingOfferCode, subscription: PricingProduct, extras: PurchaseExtras) -> [SubscriptionOfferProblem] {
        let typed = SubscriptionOfferRules.customCode(custom.code)
        let own = OfferCodeChangeBuilder.changeID(appID: app.id, productID: subscription.productID, offerCodeID: code.id, what: "custom.\(typed)")
        let taken = ExistingOfferCode.customCodes(of: extras.offerCodes).union(queuedCustomCodes(for: subscription, except: own))
        return (code.isActive ? [] : [.notActive]) + custom.problems(taken: taken, today: today)
    }

    func problems(for batch: NewOneTimeCodes, code: ExistingOfferCode) -> [SubscriptionOfferProblem] {
        (code.isActive ? [] : [.notActive]) + batch.problems(today: today)
    }

    @discardableResult
    func queue(_ code: NewOfferCode, for subscription: PricingProduct, extras: PurchaseExtras, source: ChangeSource, evidence: [String] = []) -> PendingChange {
        let change = OfferCodeChangeBuilder(app: app).change(
            for: code, subscription: subscription, problems: problems(for: code, subscription: subscription, extras: extras),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queue(
        _ custom: NewCustomCode, for code: ExistingOfferCode, subscription: PricingProduct, extras: PurchaseExtras,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = OfferCodeChangeBuilder(app: app).customCodeChange(
            custom, for: code, subscription: subscription,
            problems: problems(for: custom, code: code, subscription: subscription, extras: extras), source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queue(
        _ batch: NewOneTimeCodes, for code: ExistingOfferCode, subscription: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = OfferCodeChangeBuilder(app: app).oneTimeCodesChange(
            batch, for: code, subscription: subscription, problems: problems(for: batch, code: code), source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    /// Why a deactivation can't go: it's off already.
    func problems(forDeactivating target: OfferCodeChangeBuilder.Target, in code: ExistingOfferCode) -> [SubscriptionOfferProblem] {
        let isActive = switch target {
        case .offerCode: code.isActive
        case let .customCode(custom): custom.isActive && code.isActive
        case let .oneTimeCodes(batch): batch.isActive && code.isActive
        }
        return isActive ? [] : [.notActive]
    }

    @discardableResult
    func queueDeactivation(
        of target: OfferCodeChangeBuilder.Target, in code: ExistingOfferCode, subscription: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = OfferCodeChangeBuilder(app: app).deactivation(
            of: target, in: code, subscription: subscription, problems: problems(forDeactivating: target, in: code),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    // MARK: - Queued

    /// The subscription's offer changes waiting in Review & Push.
    func queued(for subscription: PricingProduct) -> [PendingChange] {
        SubscriptionOfferChanges.queued(in: queue, appID: app.id, subscriptionID: subscription.id)
    }

    /// Someone else's change with this id, which a proposal mustn't replace.
    func othersChange(id: PendingChange.ID, source: ChangeSource) -> PendingChange? {
        queue.change(id: id).flatMap { $0.source == source ? nil : $0 }
    }

    private func queuedCreates(for subscription: PricingProduct, except id: PendingChange.ID) -> [PendingChange] {
        queued(for: subscription).filter { $0.id != id && $0.creation != nil }
    }

    private func queuedCustomCodes(for subscription: PricingProduct, except id: PendingChange.ID) -> Set<String> {
        let codes = queued(for: subscription).filter { $0.id != id }.flatMap(OfferCodeChangeBuilder.customCodes(in:))
        return Set(codes.map { SubscriptionOfferRules.customCode($0.code) })
    }
}
