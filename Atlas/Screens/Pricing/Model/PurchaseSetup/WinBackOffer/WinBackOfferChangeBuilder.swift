//
//  WinBackOfferChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns a win-back offer into Review & Push: a new one (created with its
/// prices in every territory it runs in, `SubscriptionOfferWrite`), new
/// settings for one App Store Connect has (eligibility, dates, priority,
/// promotion: the attributes it lets change, with the old ones to restore
/// and a conflict check), or deleting one. Each is its own change,
/// `winBackOffer.<appID>.<productID>.<offerId>`.
struct WinBackOfferChangeBuilder {
    let app: StoreApp

    static let idPrefix = "winBackOffer."

    static func changeID(appID: StoreApp.ID, productID: String, offerID: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(offerID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The new offer a change creates, if it creates one.
    static func offer(in change: PendingChange) -> NewWinBackOffer? {
        change.requests.lazy.compactMap(SubscriptionOfferWrite.init).compactMap(NewWinBackOffer.init).first
    }

    /// A new offer for `subscription`, which App Store Connect has.
    func change(
        for offer: NewWinBackOffer,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: subscription.productID, offerID: offer.trimmedOfferID)
        let plan = OfferPricesPlan(subscriptionID: subscription.id, terms: offer.terms)
        var change = SubscriptionOfferChanges.change(.init(
            id: id, app: app, subscription: subscription,
            title: String(localized: "Win-back offer “\(offer.trimmedName)”"),
            oldValue: String(localized: "None"), newValue: offer.terms.summary, source: source, problems: problems,
            requests: [SubscriptionOfferWrite.create(.winBack, attributes: offer.attributes, plan: plan)], date: date
        ))
        let settings = offer.settings
        let fields = [
            (id: "name", title: String(localized: "Reference name"), value: offer.trimmedName),
            (id: "offerId", title: String(localized: "Offer ID"), value: offer.trimmedOfferID),
        ] + SubscriptionOfferChanges.termFields(offer.terms) + [
            (id: "eligibility", title: String(localized: "Who can get it"), value: settings.eligibility.summary),
            (id: "dates", title: String(localized: "When"), value: settings.datesTitle),
            (id: "priority", title: String(localized: "Priority"), value: settings.priority.title),
            (id: "promotion", title: String(localized: "Where it shows"), value: settings.promotionIntent.title),
        ]
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Add the win-back offer “\(offer.trimmedName)” to \(subscription.name)"),
            detail: String(localized: "Apple shows it to people who used to subscribe to \(subscription.name) and are eligible."),
            source: source,
            fields: SubscriptionOfferChanges.fields(fields, source: source, evidence: evidence)
        )
        return change
    }

    /// New settings for an offer App Store Connect has: only the attributes
    /// that differ are sent, and the old ones put back on Restore.
    func settingsChange(
        for existing: ExistingWinBackOffer,
        settings: WinBackOfferSettings,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        today: Date = .now,
        at date: Date = .now
    ) -> PendingChange {
        let keys = Self.changedKeys(from: existing.settings, to: settings, startIsFixed: existing.hasStarted(today: today))
        let path = "\(SubscriptionOfferResource.winBack.path)/\(existing.id)"
        let patch = Self.patch(path: path, id: existing.id, attributes: settings.attributes, keys: keys)
        let restore = Self.patch(path: path, id: existing.id, attributes: existing.settings.attributes, keys: keys)
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, offerID: existing.offerID),
            app: app, subscription: subscription,
            title: String(localized: "Win-back offer “\(existing.referenceName)”"),
            oldValue: existing.settings.summary, newValue: settings.summary, source: source,
            problems: keys.isEmpty ? [.nothingChanged] + problems : problems,
            requests: [patch], restoreRequests: [restore],
            conflictCheck: keys.first.flatMap { Self.check(key: $0, offerID: existing.id, attributes: existing.settings.attributes) },
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// Deleting an offer App Store Connect has.
    func deletion(
        of existing: ExistingWinBackOffer,
        subscription: PricingProduct,
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, offerID: existing.offerID),
            app: app, subscription: subscription,
            title: String(localized: "Win-back offer “\(existing.referenceName)”"),
            oldValue: existing.terms.summary, newValue: String(localized: "Deleted"), source: source, problems: [],
            requests: [PushRequest(method: .delete, path: "\(SubscriptionOfferResource.winBack.path)/\(existing.id)", body: nil)],
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// The settings a queued edit sends, over the offer's own.
    static func settings(in change: PendingChange, over existing: WinBackOfferSettings) -> WinBackOfferSettings? {
        guard owns(change), let request = change.requests.first, request.method == .patch, SubscriptionOfferWrite(request) == nil,
              let attributes = (PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        else { return nil }
        let merged = existing.attributes.merging(attributes) { $1 }
        return WinBackOfferSettings(attributes: merged)
    }

    /// The attribute names whose values differ, in a fixed order.
    static func changedKeys(from old: WinBackOfferSettings, to new: WinBackOfferSettings, startIsFixed: Bool) -> [String] {
        let before = old.attributes
        let after = new.attributes
        return [
            "priority", "promotionIntent", "startDate", "endDate", "customerEligibilityPaidSubscriptionDurationInMonths",
            "customerEligibilityTimeSinceLastSubscribedInMonths", "customerEligibilityWaitBetweenOffersInMonths",
        ].filter { key in
            !(startIsFixed && key == "startDate") && !NSDictionary(dictionary: [key: before[key] ?? NSNull()]).isEqual(to: [key: after[key] ?? NSNull()])
        }
    }

    private static func patch(path: String, id: String, attributes: [String: Any], keys: [String]) -> PushRequest {
        let sent = attributes.filter { keys.contains($0.key) }
        return PushPagedRead.request(.patch, path, ["data": ["type": SubscriptionOfferResource.winBack.type, "id": id, "attributes": sent]])
    }

    /// The first changed attribute as it was, checked before the push.
    private static func check(key: String, offerID: String, attributes: [String: Any]) -> ConflictCheck? {
        let path = "\(SubscriptionOfferResource.winBack.path)/\(offerID)?fields%5BwinBackOffers%5D=\(key)"
        if key == "customerEligibilityTimeSinceLastSubscribedInMonths" {
            let minimum = (attributes[key] as? [String: Any])?["minimum"] as? Int
            return ConflictCheck(path: path, keyPath: ["data", "attributes", key, "minimum"], expected: minimum.map(String.init))
        }
        let value = attributes[key]
        let expected: String? = switch value {
        case let text as String: text
        case let number as Int: String(number)
        default: nil
        }
        return ConflictCheck(path: path, keyPath: ["data", "attributes", key], expected: expected)
    }
}
