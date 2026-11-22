//
//  ExistingIntroductoryOffer.swift
//  Atlas
//

import Foundation

/// An introductory offer a subscription has in App Store Connect, as one
/// territory's resource: App Store Connect keeps one per territory, so a
/// free trial everywhere is ~175 of these with the same terms.
struct ExistingIntroductoryOffer: Hashable, Sendable {
    var id: String
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var numberOfPeriods: Int
    var territoryID: String?
    var startDate: String?
    var endDate: String?
    /// What it costs in its territory; nil for a free trial.
    var customerPrice: Decimal?

    /// The same offer in several territories, for lists and get_subscriptions.
    struct Terms: Hashable, Sendable {
        var mode: OfferPaymentMode
        var duration: IntroductoryOfferDuration
        var numberOfPeriods: Int
        var startDate: String?
        var endDate: String?
        var territoryIDs: [String]
        /// The price in the United States, when it runs there.
        var usPrice: Decimal?

        /// "Free for 1 week · 175 countries or regions".
        var summary: String {
            let offer = NewIntroductoryOffer(mode: mode, duration: duration, numberOfPeriods: numberOfPeriods, price: usPrice)
            return "\(offer.summary) · " + String(localized: "\(territoryIDs.count) countries or regions")
        }
    }

    /// One resource of `GET /v1/subscriptions/{id}/introductoryOffers`;
    /// nil when its mode or duration isn't one Atlas knows. `included` holds
    /// its price points.
    init?(resource: [String: Any], included: [[String: Any]] = []) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        self.id = id
        self.mode = mode
        self.duration = duration
        numberOfPeriods = attributes["numberOfPeriods"] as? Int ?? 1
        territoryID = PushPagedRead.relationshipID("territory", of: resource)
        startDate = attributes["startDate"] as? String
        endDate = attributes["endDate"] as? String
        let pointID = PushPagedRead.relationshipID("subscriptionPricePoint", of: resource)
        customerPrice = included.first { $0["id"] as? String == pointID && pointID != nil }.flatMap(PushPagedRead.customerPrice(of:))
    }

    init(
        id: String, mode: OfferPaymentMode, duration: IntroductoryOfferDuration, numberOfPeriods: Int = 1, territoryID: String?,
        startDate: String? = nil, endDate: String? = nil, customerPrice: Decimal? = nil
    ) {
        self.id = id
        self.mode = mode
        self.duration = duration
        self.numberOfPeriods = numberOfPeriods
        self.territoryID = territoryID
        self.startDate = startDate
        self.endDate = endDate
        self.customerPrice = customerPrice
    }

    /// The offers grouped by their terms, the most territories first.
    static func terms(of offers: [ExistingIntroductoryOffer]) -> [Terms] {
        let groups = Dictionary(grouping: offers) { offer in
            "\(offer.mode.rawValue)|\(offer.duration.rawValue)|\(offer.numberOfPeriods)|\(offer.startDate ?? "")|\(offer.endDate ?? "")"
        }
        return groups.values.compactMap { group -> Terms? in
            guard let first = group.first else { return nil }
            return Terms(
                mode: first.mode, duration: first.duration, numberOfPeriods: first.numberOfPeriods,
                startDate: first.startDate, endDate: first.endDate,
                territoryIDs: group.compactMap(\.territoryID).sorted(),
                usPrice: group.first { $0.territoryID == NewSubscription.baseTerritoryID }?.customerPrice
            )
        }
        .sorted { $0.territoryIDs.count > $1.territoryIDs.count }
    }

    /// The terms as Pricing's Offers tab lists an offer; its prices follow
    /// each territory's subscription price by the US share.
    static func subscriptionOffer(_ terms: Terms, index: Int, subscriptionPrice: Decimal?) -> SubscriptionOffer {
        let share: Decimal = if let usPrice = terms.usPrice, let subscriptionPrice, subscriptionPrice > 0 { usPrice / subscriptionPrice } else { 0 }
        let dates = [terms.startDate.map { String(localized: "from \($0)") }, terms.endDate.map { String(localized: "until \($0)") }]
            .compactMap(\.self).joined(separator: " ")
        return SubscriptionOffer(
            id: "introductory.\(index)",
            kind: .introductory,
            name: NewIntroductoryOffer(mode: terms.mode, duration: terms.duration, numberOfPeriods: terms.numberOfPeriods, price: terms.usPrice).summary,
            eligibility: String(localized: "New subscribers · \(terms.territoryIDs.count) countries or regions") + (dates.isEmpty ? "" : " · \(dates)"),
            paymentMode: terms.mode,
            duration: terms.numberOfPeriods > 1 ? "\(terms.numberOfPeriods) × \(terms.duration.title)" : terms.duration.title,
            rule: String(localized: "As set in App Store Connect, in each country or region"),
            priceShare: share
        )
    }
}
