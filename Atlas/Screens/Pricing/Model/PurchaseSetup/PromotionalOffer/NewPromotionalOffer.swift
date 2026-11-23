//
//  NewPromotionalOffer.swift
//  Atlas
//

import Foundation

/// A promotional offer to create for a subscription, as New Promotional
/// Offer… or an assistant's `propose_promotional_offer` fills it in: a
/// discount or free time the app offers its own current or lapsed
/// subscribers, signed by the app's server, with a reference name and the
/// identifier the app's code asks StoreKit for (`offerCode`). Neither is
/// shown to customers, and neither can change once it's created.
struct NewPromotionalOffer: Hashable, Sendable {
    /// `name`: only the developer sees it.
    var name: String
    /// `offerCode`: the identifier the app passes to StoreKit.
    var identifier: String
    var terms: OfferTerms

    /// "Win back · $1.99 a month for 3 × 1 month".
    var summary: String {
        "\(trimmedName) · \(terms.summary)"
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The `attributes` App Store Connect creates it with.
    var attributes: [String: Any] {
        [
            "name": trimmedName,
            "offerCode": trimmedIdentifier,
            "duration": terms.duration.rawValue,
            "offerMode": terms.mode.apiValue,
            "numberOfPeriods": terms.sentPeriods,
        ]
    }

    /// The offer a queued create carries back; nil for another request.
    init?(_ write: SubscriptionOfferWrite) {
        let attributes = write.attributes
        guard write.resource == .promotional, write.isCreate,
              let name = attributes["name"] as? String, let identifier = attributes["offerCode"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        let terms = OfferTerms(mode: mode, duration: duration, numberOfPeriods: attributes["numberOfPeriods"] as? Int ?? 1)
        self.init(name: name, identifier: identifier, terms: write.plan.applied(to: terms))
    }

    init(name: String, identifier: String, terms: OfferTerms) {
        self.name = name
        self.identifier = identifier
        self.terms = terms
    }
}
