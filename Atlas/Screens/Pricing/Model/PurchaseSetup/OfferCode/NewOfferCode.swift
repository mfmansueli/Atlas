//
//  NewOfferCode.swift
//  Atlas
//

import Foundation

/// An offer code to create for a subscription, as New Offer Code… or an
/// assistant's `propose_offer_code` fills it in: free time or a lower price
/// that people redeem with a code (in the App Store, in the app or by link),
/// for the eligibilities chosen. The push creates it with its prices, then
/// the custom code and one-time codes it comes with, if any. Its name is
/// only seen by the developer; the custom code is what customers type.
struct NewOfferCode: Hashable, Sendable {
    /// `name`.
    var name: String
    var eligibilities: [OfferCodeCustomerEligibility] = [.new]
    var offerEligibility = OfferCodeOfferEligibility.stackWithIntroOffers
    var terms: OfferTerms
    /// `autoRenewEnabled`: nil leaves App Store Connect's default (it renews).
    var autoRenews: Bool?
    var customCode: NewCustomCode?
    var oneTimeCodes: NewOneTimeCodes?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The `attributes` App Store Connect creates it with.
    var attributes: [String: Any] {
        var attributes: [String: Any] = [
            "name": trimmedName,
            "customerEligibilities": OfferCodeCustomerEligibility.sorted(eligibilities).map(\.rawValue),
            "offerEligibility": offerEligibility.rawValue,
            "duration": terms.duration.rawValue,
            "offerMode": terms.mode.apiValue,
            "numberOfPeriods": terms.sentPeriods,
        ]
        if let autoRenews { attributes["autoRenewEnabled"] = autoRenews }
        return attributes
    }

    /// "New subscribers · Free for 1 month".
    var summary: String {
        "\(OfferCodeCustomerEligibility.title(of: OfferCodeCustomerEligibility.sorted(eligibilities))) · \(terms.summary)"
    }

    init(
        name: String, eligibilities: [OfferCodeCustomerEligibility] = [.new],
        offerEligibility: OfferCodeOfferEligibility = .stackWithIntroOffers, terms: OfferTerms, autoRenews: Bool? = nil,
        customCode: NewCustomCode? = nil, oneTimeCodes: NewOneTimeCodes? = nil
    ) {
        self.name = name
        self.eligibilities = eligibilities
        self.offerEligibility = offerEligibility
        self.terms = terms
        self.autoRenews = autoRenews
        self.customCode = customCode
        self.oneTimeCodes = oneTimeCodes
    }

    /// The offer code a queued create carries back; nil for another request.
    init?(_ write: SubscriptionOfferWrite) {
        let attributes = write.attributes
        guard write.resource == .offerCode, write.isCreate, let name = attributes["name"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        let terms = OfferTerms(mode: mode, duration: duration, numberOfPeriods: attributes["numberOfPeriods"] as? Int ?? 1)
        self.init(
            name: name,
            eligibilities: (attributes["customerEligibilities"] as? [String] ?? []).compactMap(OfferCodeCustomerEligibility.init(rawValue:)),
            offerEligibility: (attributes["offerEligibility"] as? String).flatMap(OfferCodeOfferEligibility.init(rawValue:)) ?? .stackWithIntroOffers,
            terms: write.plan.applied(to: terms),
            autoRenews: attributes["autoRenewEnabled"] as? Bool
        )
    }
}
