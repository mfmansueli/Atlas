//
//  ExistingPromotionalOffer.swift
//  Atlas
//

import Foundation

/// A promotional offer a subscription has in App Store Connect
/// (`GET /v1/subscriptions/{id}/promotionalOffers`), with where it runs,
/// its US price and the territories priced apart from it.
struct ExistingPromotionalOffer: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var identifier: String
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var numberOfPeriods: Int
    var prices = ExistingOfferPrices()

    /// `GET` the subscription's promotional offers.
    static func listPath(subscriptionID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/promotionalOffers"
            + "?fields%5BsubscriptionPromotionalOffers%5D=name,offerCode,duration,offerMode,numberOfPeriods&limit=200"
    }

    /// One resource of the list; nil when its mode or duration isn't one
    /// Atlas knows.
    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        self.id = id
        name = attributes["name"] as? String ?? ""
        identifier = attributes["offerCode"] as? String ?? ""
        self.mode = mode
        self.duration = duration
        numberOfPeriods = attributes["numberOfPeriods"] as? Int ?? 1
    }

    init(
        id: String, name: String, identifier: String, mode: OfferPaymentMode, duration: IntroductoryOfferDuration,
        numberOfPeriods: Int = 1, prices: ExistingOfferPrices = ExistingOfferPrices()
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.mode = mode
        self.duration = duration
        self.numberOfPeriods = numberOfPeriods
        self.prices = prices
    }

    /// Its terms, as the sheet edits them: the US price, everywhere it
    /// runs, and the territories whose price isn't the equalized one.
    var terms: OfferTerms {
        OfferTerms(
            mode: mode, duration: duration, numberOfPeriods: numberOfPeriods, price: prices.usPrice,
            territories: .chosen(prices.territoryIDs), territoryPrices: mode == .freeTrial ? [:] : prices.pricedApart
        )
    }

    /// The Offers tab's row and detail.
    func subscriptionOffer(subscriptionPrice: Decimal?) -> SubscriptionOffer {
        SubscriptionOffer(
            id: Self.offerID(id),
            kind: .promotional,
            name: name.isEmpty ? terms.summary : name,
            eligibility: String(localized: "Subscribers your app offers it to · \(identifier) · \(prices.territoriesTitle)"),
            paymentMode: mode,
            duration: terms.durationTitle,
            rule: terms.summary,
            priceShare: terms.priceShare(of: subscriptionPrice)
        )
    }

    /// `promotional.<id>`: the Offers tab's id for it.
    static func offerID(_ id: String) -> SubscriptionOffer.ID {
        "promotional.\(id)"
    }
}
