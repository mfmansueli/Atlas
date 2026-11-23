//
//  SubscriptionOfferChanges.swift
//  Atlas
//

import Foundation

/// What the promotional offer, win-back offer and offer code changes have
/// in common: Review & Push lists each under "Subscription Pricing ·
/// <subscription>", its `groupID` is the subscription's App Store Connect
/// ID, and a new offer shows as a creation with its fields.
enum SubscriptionOfferChanges {
    /// What one change for `subscription` is made of.
    struct Spec {
        var id: PendingChange.ID
        var app: StoreApp
        var subscription: PricingProduct
        var title: String
        var oldValue: String
        var newValue: String
        var source: ChangeSource
        var problems: [SubscriptionOfferProblem]
        var requests: [PushRequest]
        var restoreRequests: [PushRequest] = []
        var conflictCheck: ConflictCheck?
        var date: Date
    }

    /// One change for `subscription`.
    static func change(_ spec: Spec) -> PendingChange {
        PendingChange(
            id: spec.id,
            appID: spec.app.id,
            section: .subscriptionPricing,
            group: String(localized: "Subscription Pricing · \(spec.subscription.name)"),
            groupID: spec.subscription.id,
            title: spec.title,
            oldValue: spec.oldValue,
            newValue: spec.newValue,
            source: spec.source,
            blockedReason: spec.problems.first?.message,
            requests: spec.requests,
            restoreRequests: spec.restoreRequests,
            conflictCheck: spec.conflictCheck,
            createdAt: spec.date
        )
    }

    /// A creation's fields, then what the assistant based it on.
    static func fields(_ fields: [(id: String, title: String, value: String)], source: ChangeSource, evidence: [String]) -> [PendingChangePart] {
        var fields = fields
        if !evidence.isEmpty { fields.append(("evidence", String(localized: "Found in"), evidence.joined(separator: "\n"))) }
        return fields.map { PendingChangePart(id: $0.id, title: $0.title, oldValue: "", newValue: $0.value, source: source) }
    }

    /// The terms' fields: type, duration, price and where.
    static func termFields(_ terms: OfferTerms) -> [(id: String, title: String, value: String)] {
        var fields: [(id: String, title: String, value: String)] = [
            ("mode", String(localized: "Type"), terms.mode.title),
            ("duration", String(localized: "Duration"), terms.durationTitle),
        ]
        if let prices = terms.pricesTitle { fields.append(("price", String(localized: "Price"), prices)) }
        fields.append(("territories", String(localized: "Countries or regions"), terms.territories.title))
        return fields
    }

    /// Whether a change is a promotional offer's, win-back offer's or offer code's.
    static func owns(_ change: PendingChange) -> Bool {
        PromotionalOfferChangeBuilder.owns(change) || WinBackOfferChangeBuilder.owns(change) || OfferCodeChangeBuilder.owns(change)
    }

    /// The offer changes for a subscription waiting in Review & Push.
    @MainActor
    static func queued(in queue: ChangeQueue, appID: StoreApp.ID, subscriptionID: String) -> [PendingChange] {
        queue.changes(for: appID, section: .subscriptionPricing).filter { owns($0) && $0.groupID == subscriptionID }
    }

    /// Its kind, for get_subscriptions and the Offers tab.
    static func kind(of change: PendingChange) -> OfferKind? {
        if PromotionalOfferChangeBuilder.owns(change) { return .promotional }
        if WinBackOfferChangeBuilder.owns(change) { return .winBack }
        if OfferCodeChangeBuilder.owns(change) { return .offerCode }
        return nil
    }
}
