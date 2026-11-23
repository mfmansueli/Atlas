//
//  ExistingOfferCode.swift
//  Atlas
//

import Foundation

/// An offer code a subscription has in App Store Connect
/// (`GET /v1/subscriptions/{id}/offerCodes`), with its custom codes,
/// one-time code batches, where it runs and its US price.
struct ExistingOfferCode: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var eligibilities: [OfferCodeCustomerEligibility]
    var offerEligibility: OfferCodeOfferEligibility
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var numberOfPeriods: Int
    var isActive: Bool
    var autoRenews: Bool?
    var totalNumberOfCodes: Int?
    var customCodes: [ExistingCustomCode] = []
    var oneTimeCodes: [ExistingOneTimeCodes] = []
    var prices = ExistingOfferPrices()

    static func listPath(subscriptionID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/offerCodes?fields%5BsubscriptionOfferCodes%5D=name,customerEligibilities,"
            + "offerEligibility,duration,offerMode,numberOfPeriods,totalNumberOfCodes,active,autoRenewEnabled&limit=200"
    }

    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        self.id = id
        name = attributes["name"] as? String ?? ""
        eligibilities = (attributes["customerEligibilities"] as? [String] ?? []).compactMap(OfferCodeCustomerEligibility.init(rawValue:))
        offerEligibility = (attributes["offerEligibility"] as? String).flatMap(OfferCodeOfferEligibility.init(rawValue:)) ?? .stackWithIntroOffers
        self.mode = mode
        self.duration = duration
        numberOfPeriods = attributes["numberOfPeriods"] as? Int ?? 1
        isActive = attributes["active"] as? Bool ?? true
        autoRenews = attributes["autoRenewEnabled"] as? Bool
        totalNumberOfCodes = attributes["totalNumberOfCodes"] as? Int
    }

    init(
        id: String, name: String, eligibilities: [OfferCodeCustomerEligibility], offerEligibility: OfferCodeOfferEligibility = .stackWithIntroOffers,
        mode: OfferPaymentMode, duration: IntroductoryOfferDuration, numberOfPeriods: Int = 1, isActive: Bool = true,
        customCodes: [ExistingCustomCode] = [], oneTimeCodes: [ExistingOneTimeCodes] = [], prices: ExistingOfferPrices = ExistingOfferPrices()
    ) {
        self.id = id
        self.name = name
        self.eligibilities = eligibilities
        self.offerEligibility = offerEligibility
        self.mode = mode
        self.duration = duration
        self.numberOfPeriods = numberOfPeriods
        self.isActive = isActive
        self.customCodes = customCodes
        self.oneTimeCodes = oneTimeCodes
        self.prices = prices
    }

    var terms: OfferTerms {
        OfferTerms(mode: mode, duration: duration, numberOfPeriods: numberOfPeriods, price: prices.usPrice, territories: .chosen(prices.territoryIDs))
    }

    /// "1 custom code · 2 batches of one-time codes".
    var codesSummary: String {
        var parts: [String] = []
        if !customCodes.isEmpty { parts.append(customCodes.map(\.code).joined(separator: ", ")) }
        let codes = oneTimeCodes.reduce(0) { $0 + $1.numberOfCodes }
        if codes > 0 { parts.append(String(localized: "\(codes.formatted()) one-time codes")) }
        return parts.isEmpty ? String(localized: "No codes yet") : parts.joined(separator: " · ")
    }

    /// Every custom code of `codes`, as customers type them.
    static func customCodes(of codes: [ExistingOfferCode]) -> Set<String> {
        Set(codes.flatMap(\.customCodes).map { SubscriptionOfferRules.customCode($0.code) })
    }

    /// The Offers tab's row and detail.
    func subscriptionOffer(subscriptionPrice: Decimal?) -> SubscriptionOffer {
        var eligibility = OfferCodeCustomerEligibility.title(of: eligibilities) + " · " + codesSummary
        if !isActive { eligibility += " · " + String(localized: "inactive") }
        return SubscriptionOffer(
            id: Self.offerID(id),
            kind: .offerCode,
            name: name.isEmpty ? terms.summary : name,
            eligibility: eligibility,
            paymentMode: mode,
            duration: terms.durationTitle,
            rule: "\(terms.summary) · \(prices.territoriesTitle)",
            priceShare: terms.priceShare(of: subscriptionPrice)
        )
    }

    /// `offerCode.<id>`: the Offers tab's id for it.
    static func offerID(_ id: String) -> SubscriptionOffer.ID {
        "offerCode.\(id)"
    }
}
