//
//  InAppPurchaseOfferCodeQueue.swift
//  Atlas
//

import Foundation

/// Checks and queues an in-app purchase's offer codes the same way from
/// Pricing's sheets and `propose_in_app_purchase_offer_code`: what App
/// Store Connect has for the purchase (`PurchaseExtras`) and what waits in
/// Review & Push decide what's refused, and each becomes its own change.
@MainActor
struct InAppPurchaseOfferCodeQueue {
    let app: StoreApp
    let queue: ChangeQueue
    var today: Date = .now

    private var builder: InAppPurchaseOfferCodeChangeBuilder {
        InAppPurchaseOfferCodeChangeBuilder(app: app)
    }

    // MARK: - New offer codes

    func problems(for code: NewInAppPurchaseOfferCode, purchase: PricingProduct, extras: PurchaseExtras) -> [SubscriptionOfferProblem] {
        let own = InAppPurchaseOfferCodeChangeBuilder.changeID(appID: app.id, productID: purchase.productID, name: code.trimmedName)
        let names = queued(for: purchase).filter { $0.id != own && $0.creation != nil }
            .compactMap { InAppPurchaseOfferCodeChangeBuilder.offerCode(in: $0)?.trimmedName }
        return code.problems(
            purchasePrice: purchase.basePrice, existing: extras.inAppPurchaseOfferCodes,
            takenNames: Set(names), takenCustomCodes: queuedCustomCodes(except: own), today: today
        )
    }

    @discardableResult
    func queue(
        _ code: NewInAppPurchaseOfferCode, for purchase: PricingProduct, extras: PurchaseExtras,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = builder.change(
            for: code, purchase: purchase, problems: problems(for: code, purchase: purchase, extras: extras),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    // MARK: - Codes for one App Store Connect has

    func problems(
        for custom: NewCustomCode, code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct, extras: PurchaseExtras
    ) -> [SubscriptionOfferProblem] {
        let typed = SubscriptionOfferRules.customCode(custom.code)
        let own = InAppPurchaseOfferCodeChangeBuilder.changeID(appID: app.id, productID: purchase.productID, offerCodeID: code.id, what: "custom.\(typed)")
        let taken = ExistingInAppPurchaseOfferCode.customCodes(of: extras.inAppPurchaseOfferCodes).union(queuedCustomCodes(except: own))
        return (code.isActive ? [] : [.notActive]) + custom.problems(taken: taken, today: today)
    }

    func problems(for batch: NewOneTimeCodes, code: ExistingInAppPurchaseOfferCode) -> [SubscriptionOfferProblem] {
        (code.isActive ? [] : [.notActive]) + batch.problems(today: today)
    }

    @discardableResult
    func queue(
        _ custom: NewCustomCode, for code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct, extras: PurchaseExtras,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = builder.customCodeChange(
            custom, for: code, purchase: purchase,
            problems: problems(for: custom, code: code, purchase: purchase, extras: extras), source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    @discardableResult
    func queue(
        _ batch: NewOneTimeCodes, for code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = builder.oneTimeCodesChange(
            batch, for: code, purchase: purchase, problems: problems(for: batch, code: code), source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    // MARK: - Deactivating

    /// Why a deactivation can't go: it's off already.
    func problems(forDeactivating target: OfferCodeChangeBuilder.Target, in code: ExistingInAppPurchaseOfferCode) -> [SubscriptionOfferProblem] {
        let isActive = switch target {
        case .offerCode: code.isActive
        case let .customCode(custom): custom.isActive && code.isActive
        case let .oneTimeCodes(batch): batch.isActive && code.isActive
        }
        return isActive ? [] : [.notActive]
    }

    @discardableResult
    func queueDeactivation(
        of target: OfferCodeChangeBuilder.Target, in code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct,
        source: ChangeSource, evidence: [String] = []
    ) -> PendingChange {
        let change = builder.deactivation(
            of: target, in: code, purchase: purchase, problems: problems(forDeactivating: target, in: code),
            source: source, evidence: evidence, at: today
        )
        queue.upsert(change)
        return change
    }

    // MARK: - Queued

    /// The purchase's offer code changes waiting in Review & Push.
    func queued(for purchase: PricingProduct) -> [PendingChange] {
        queue.changes(for: app.id, section: .subscriptionPricing).filter { InAppPurchaseOfferCodeChangeBuilder.owns($0) && $0.groupID == purchase.id }
    }

    /// Someone else's change with this id, which a proposal mustn't replace.
    func othersChange(id: PendingChange.ID, source: ChangeSource) -> PendingChange? {
        queue.change(id: id).flatMap { $0.source == source ? nil : $0 }
    }

    /// The custom codes every offer code change of the app waiting in
    /// Review & Push makes (they're unique for the app), but `id`'s.
    private func queuedCustomCodes(except id: PendingChange.ID) -> Set<String> {
        let changes = queue.changes(for: app.id, section: .subscriptionPricing).filter { $0.id != id }
        let codes = changes.flatMap { InAppPurchaseOfferCodeChangeBuilder.customCodes(in: $0) + OfferCodeChangeBuilder.customCodes(in: $0) }
        return Set(codes.map { SubscriptionOfferRules.customCode($0.code) })
    }
}
