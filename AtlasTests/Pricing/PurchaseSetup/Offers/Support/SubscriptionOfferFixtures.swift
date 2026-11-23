//
//  SubscriptionOfferFixtures.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// App Store Connect's answers for one subscription's offers: a paid
/// promotional offer in the United States and Brazil, a free win-back
/// offer, and an offer code with a custom code and a batch of one-time
/// codes, as `SubscriptionOffersReader` reads them.
enum SubscriptionOfferFixtures {
    static func remote(subscriptionID: String) -> [String: Data] {
        [
            ExistingPromotionalOffer.listPath(subscriptionID: subscriptionID): json("""
            {"data":[{"type":"subscriptionPromotionalOffers","id":"po1","attributes":{"name":"Come back","offerCode":"come_back",\
            "duration":"ONE_MONTH","offerMode":"PAY_AS_YOU_GO","numberOfPeriods":3}}]}
            """),
            SubscriptionOfferResource.promotional.pricesPath(offerID: "po1"): json("""
            {"data":[\(price("pp1", "USA", "spUSA")),\(price("pp2", "BRA", "spBRA"))],
            "included":[{"type":"subscriptionPricePoints","id":"spUSA","attributes":{"customerPrice":"2.99"}},
            {"type":"subscriptionPricePoints","id":"spBRA","attributes":{"customerPrice":"9.90"}}]}
            """),
            ExistingWinBackOffer.listPath(subscriptionID: subscriptionID): json("""
            {"data":[{"type":"winBackOffers","id":"wb1","attributes":{"referenceName":"We miss you","offerId":"we_miss_you",\
            "duration":"ONE_MONTH","offerMode":"FREE_TRIAL","periodCount":1,"customerEligibilityPaidSubscriptionDurationInMonths":2,\
            "customerEligibilityTimeSinceLastSubscribedInMonths":{"minimum":1,"maximum":6},\
            "customerEligibilityWaitBetweenOffersInMonths":6,"startDate":"2099-01-01","endDate":null,"priority":"HIGH",\
            "promotionIntent":"NOT_PROMOTED"}}]}
            """),
            SubscriptionOfferResource.winBack.pricesPath(offerID: "wb1"): json("""
            {"data":[\(price("wp1", "USA", nil))]}
            """),
            ExistingOfferCode.listPath(subscriptionID: subscriptionID): json("""
            {"data":[{"type":"subscriptionOfferCodes","id":"oc1","attributes":{"name":"Podcast listeners",\
            "customerEligibilities":["NEW","EXPIRED"],"offerEligibility":"STACK_WITH_INTRO_OFFERS","duration":"THREE_MONTHS",\
            "offerMode":"FREE_TRIAL","numberOfPeriods":1,"totalNumberOfCodes":1500,"active":true,"autoRenewEnabled":true}}]}
            """),
            SubscriptionOfferResource.offerCode.pricesPath(offerID: "oc1"): json("""
            {"data":[\(price("op1", "USA", nil)),\(price("op2", "GBR", nil))]}
            """),
            ExistingCustomCode.listPath(offerCodeID: "oc1"): json("""
            {"data":[{"type":"subscriptionOfferCodeCustomCodes","id":"cc1","attributes":{"customCode":"LUMENPOD",\
            "numberOfCodes":1000,"expirationDate":"2099-12-31","active":true}}]}
            """),
            ExistingOneTimeCodes.listPath(offerCodeID: "oc1"): json("""
            {"data":[{"type":"subscriptionOfferCodeOneTimeUseCodes","id":"ot1","attributes":{"numberOfCodes":500,\
            "createdDate":"2026-11-02","expirationDate":"2099-03-31","active":true,"environment":"PRODUCTION"}}]}
            """),
        ]
    }

    private static func price(_ id: String, _ territory: String, _ point: String?) -> String {
        var relationships = #""territory":{"data":{"type":"territories","id":"\#(territory)"}}"#
        if let point { relationships += #","subscriptionPricePoint":{"data":{"type":"subscriptionPricePoints","id":"\#(point)"}}"# }
        return #"{"type":"prices","id":"\#(id)","relationships":{\#(relationships)}}"#
    }

    private static func json(_ text: String) -> Data {
        Data(text.utf8)
    }
}
