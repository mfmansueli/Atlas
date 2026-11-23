//
//  PromotionalOfferChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns a promotional offer into Review & Push: a new one (created with
/// its prices in every territory it runs in, `SubscriptionOfferWrite`),
/// new prices for one App Store Connect has (the only thing it lets
/// change), or deleting one. Each is its own change,
/// `promotionalOffer.<appID>.<productID>.<identifier>`, so proposing again
/// for the same offer replaces it.
struct PromotionalOfferChangeBuilder {
    let app: StoreApp

    static let idPrefix = "promotionalOffer."

    static func changeID(appID: StoreApp.ID, productID: String, identifier: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(identifier)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The new offer a change creates, if it creates one.
    static func offer(in change: PendingChange) -> NewPromotionalOffer? {
        change.requests.lazy.compactMap(SubscriptionOfferWrite.init).compactMap(NewPromotionalOffer.init).first
    }

    /// A new offer for `subscription`, which App Store Connect has.
    func change(
        for offer: NewPromotionalOffer,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: subscription.productID, identifier: offer.trimmedIdentifier)
        let plan = OfferPricesPlan(subscriptionID: subscription.id, terms: offer.terms)
        var change = SubscriptionOfferChanges.change(.init(
            id: id, app: app, subscription: subscription,
            title: String(localized: "Promotional offer “\(offer.trimmedName)”"),
            oldValue: String(localized: "None"), newValue: offer.terms.summary, source: source, problems: problems,
            requests: [SubscriptionOfferWrite.create(.promotional, attributes: offer.attributes, plan: plan)], date: date
        ))
        let fields = [
            (id: "name", title: String(localized: "Reference name"), value: offer.trimmedName),
            (id: "identifier", title: String(localized: "Offer identifier"), value: offer.trimmedIdentifier),
        ] + SubscriptionOfferChanges.termFields(offer.terms)
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Add the promotional offer “\(offer.trimmedName)” to \(subscription.name)"),
            detail: String(localized: "Your app offers it to the subscribers it chooses, signed by your server, with the identifier \(offer.trimmedIdentifier)."),
            source: source,
            fields: SubscriptionOfferChanges.fields(fields, source: source, evidence: evidence)
        )
        return change
    }

    /// New prices for an offer App Store Connect has: `terms` keep its
    /// mode and duration, with the new US price, territories and those
    /// priced apart. Restore puts every old price back: the old US price
    /// equalized, and the old territories priced apart at their own.
    func pricesChange(
        for existing: ExistingPromotionalOffer,
        terms: OfferTerms,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let plan = OfferPricesPlan(subscriptionID: subscription.id, terms: terms)
        let old = OfferPricesPlan(subscriptionID: subscription.id, terms: existing.terms)
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, identifier: existing.identifier),
            app: app, subscription: subscription,
            title: String(localized: "Promotional offer “\(existing.name)” · prices"),
            oldValue: Self.pricesValue(existing.terms, territories: existing.prices.territoriesTitle),
            newValue: Self.pricesValue(terms, territories: terms.territories.title),
            source: source, problems: problems,
            requests: [SubscriptionOfferWrite.replacingPrices(.promotional, offerID: existing.id, plan: plan)],
            restoreRequests: existing.prices.territoryIDs.isEmpty
                ? [] : [SubscriptionOfferWrite.replacingPrices(.promotional, offerID: existing.id, plan: old)],
            conflictCheck: existing.prices.usPrice.map { Self.usPriceCheck(offerID: existing.id, expected: $0) },
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// Deleting an offer App Store Connect has: customers who redeemed it
    /// keep it; the app can't offer it again.
    func deletion(
        of existing: ExistingPromotionalOffer,
        subscription: PricingProduct,
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, identifier: existing.identifier),
            app: app, subscription: subscription,
            title: String(localized: "Promotional offer “\(existing.name)”"),
            oldValue: existing.terms.summary, newValue: String(localized: "Deleted"), source: source, problems: [],
            requests: [PushRequest(method: .delete, path: "\(SubscriptionOfferResource.promotional.path)/\(existing.id)", body: nil)],
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// Whether a change deletes the offer.
    static func isDeletion(_ change: PendingChange) -> Bool {
        owns(change) && change.requests.contains { $0.method == .delete }
    }

    /// "$1.99 a month for 3 × 1 month · 175 countries or regions".
    private static func pricesValue(_ terms: OfferTerms, territories: String) -> String {
        "\(terms.summary) · \(territories)"
    }

    /// The US price at the last read, checked before the push replaces it.
    private static func usPriceCheck(offerID: String, expected: Decimal) -> ConflictCheck {
        ConflictCheck(
            path: "/v1/subscriptionPromotionalOffers/\(offerID)/prices?filter%5Bterritory%5D=\(NewSubscription.baseTerritoryID)"
                + "&include=subscriptionPricePoint&fields%5BsubscriptionPricePoints%5D=customerPrice",
            keyPath: ["included", "0", "attributes", "customerPrice"],
            expected: OfferPricesPlan.string(expected),
            format: .currency(code: "USD", localeIdentifier: "en_US")
        )
    }
}
