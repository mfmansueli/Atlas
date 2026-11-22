//
//  IntroductoryOfferChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns an introductory offer into Review & Push: for a subscription App
/// Store Connect has, its own change, "Introductory offer" with its terms;
/// for a new subscription waiting in Review & Push, one more step of that
/// subscription's change, after its availability and starting price
/// (`{createdID:subscriptions}`). Either way the push creates the offer in
/// every territory it runs in (`IntroductoryOfferEverywhere`).
struct IntroductoryOfferChangeBuilder {
    let app: StoreApp

    static let idPrefix = "introductoryOffer."
    /// The field a new subscription's change lists the offer under.
    static let fieldID = "introductoryOffer"

    /// `introductoryOffer.<appID>.<productID>`: proposing another offer for
    /// the same subscription replaces the change.
    static func changeID(appID: StoreApp.ID, productID: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The offer a change sends: its own, or a new subscription's.
    static func offer(in change: PendingChange) -> NewIntroductoryOffer? {
        change.requests.lazy.compactMap(IntroductoryOfferEverywhere.init).first?.offer
    }

    /// An offer for `subscription`, which App Store Connect has.
    func change(
        for offer: NewIntroductoryOffer,
        subscription: PricingProduct,
        problems: [IntroductoryOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: subscription.productID)
        var change = PendingChange(
            id: id,
            appID: app.id,
            section: .subscriptionPricing,
            group: String(localized: "Subscription Pricing · \(subscription.name)"),
            title: String(localized: "Introductory offer"),
            oldValue: String(localized: "None"),
            newValue: offer.summary,
            source: source,
            blockedReason: problems.first?.message,
            requests: [IntroductoryOfferEverywhere(subscriptionID: subscription.id, offer: offer).request],
            createdAt: date
        )
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Add an introductory offer to \(subscription.name)"),
            detail: String(localized: "New subscribers of \(subscription.name) get it in \(offer.territories.title)."),
            source: source,
            fields: Self.fields(of: offer, source: source, evidence: evidence)
        )
        return change
    }

    /// A new subscription's change with `offer` as its last step, in place
    /// of the one it had.
    static func attaching(_ offer: NewIntroductoryOffer, to change: PendingChange, source: ChangeSource) -> PendingChange {
        var change = detaching(from: change)
        change.requests.append(IntroductoryOfferEverywhere(subscriptionID: PushRequest.createdIDPlaceholder(type: "subscriptions"), offer: offer).request)
        change.creation?.fields.append(PendingChangePart(
            id: fieldID,
            title: String(localized: "Introductory offer"),
            oldValue: "",
            newValue: "\(offer.summary) · \(offer.territories.title)",
            source: source
        ))
        return change
    }

    /// The change without its offer step and field.
    static func detaching(from change: PendingChange) -> PendingChange {
        var change = change
        change.requests.removeAll { IntroductoryOfferEverywhere($0) != nil }
        change.creation?.fields.removeAll { $0.id == fieldID }
        return change
    }

    static func fields(of offer: NewIntroductoryOffer, source: ChangeSource, evidence: [String]) -> [PendingChangePart] {
        var fields: [(String, String, String)] = [
            ("mode", String(localized: "Type"), offer.mode.title),
            ("duration", String(localized: "Duration"), offer.mode == .payAsYouGo
                ? String(localized: "\(offer.numberOfPeriods) × \(offer.duration.title)")
                : offer.duration.title),
        ]
        if let price = offer.formattedPrice {
            fields.append(("price", String(localized: "Price"), String(localized: "\(price) in the United States · equalized everywhere else")))
        }
        fields.append(("territories", String(localized: "Countries or regions"), offer.territories.title))
        if let start = offer.startDate { fields.append(("startDate", String(localized: "Starts"), NewIntroductoryOffer.dayString(start))) }
        if let end = offer.endDate { fields.append(("endDate", String(localized: "Ends"), NewIntroductoryOffer.dayString(end))) }
        if !evidence.isEmpty { fields.append(("evidence", String(localized: "Found in"), evidence.joined(separator: "\n"))) }
        return fields.map { PendingChangePart(id: $0.0, title: $0.1, oldValue: "", newValue: $0.2, source: source) }
    }
}
