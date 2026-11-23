//
//  MCPSubscriptionOffersJSON.swift
//  Atlas
//

import Foundation

/// A subscription's promotional offers, win-back offers and offer codes as
/// get_subscriptions returns them, each with every attribute Atlas reads,
/// its territories and US price, and the offer changes waiting in Review &
/// Push.
enum MCPSubscriptionOffersJSON {
    /// `promotionalOffers`, `winBackOffers`, `offerCodes` and `queuedOffers`
    /// for one subscription; the offers are "unknown" when they couldn't be read.
    static func fields(extras: PurchaseExtras?, queued: [PendingChange]) -> [String: JSONValue] {
        var json: [String: JSONValue] = ["queuedOffers": .array(queued.map(Self.queued))]
        guard let extras, extras.offersRead else {
            json["promotionalOffers"] = "unknown"
            json["winBackOffers"] = "unknown"
            json["offerCodes"] = "unknown"
            return json
        }
        json["promotionalOffers"] = .array(extras.promotionalOffers.map(Self.promotional))
        json["winBackOffers"] = .array(extras.winBackOffers.map(Self.winBack))
        json["offerCodes"] = .array(extras.offerCodes.map(Self.offerCode))
        return json
    }

    static func promotional(_ offer: ExistingPromotionalOffer) -> JSONValue {
        var json = terms(mode: offer.mode, duration: offer.duration, periods: offer.numberOfPeriods, prices: offer.prices)
        json["id"] = .string(offer.id)
        json["name"] = .string(offer.name)
        json["offerIdentifier"] = .string(offer.identifier)
        return .object(json)
    }

    static func winBack(_ offer: ExistingWinBackOffer) -> JSONValue {
        var json = terms(mode: offer.mode, duration: offer.duration, periods: offer.periodCount, prices: offer.prices)
        let settings = offer.settings
        json["id"] = .string(offer.id)
        json["referenceName"] = .string(offer.referenceName)
        json["offerId"] = .string(offer.offerID)
        json["paidMonths"] = .int(settings.eligibility.paidMonths)
        json["sinceLastSubscribed"] = [
            "minimum": .int(settings.eligibility.sinceLastSubscribed.lowerBound),
            "maximum": .int(settings.eligibility.sinceLastSubscribed.upperBound),
        ]
        json["waitMonths"] = settings.eligibility.waitMonths.map(JSONValue.int) ?? .null
        json["startDate"] = .string(NewIntroductoryOffer.dayString(settings.startDate))
        json["endDate"] = settings.endDate.map { .string(NewIntroductoryOffer.dayString($0)) } ?? .null
        json["priority"] = .string(settings.priority.rawValue)
        json["promotionIntent"] = .string(settings.promotionIntent.rawValue)
        return .object(json)
    }

    static func offerCode(_ code: ExistingOfferCode) -> JSONValue {
        var json = terms(mode: code.mode, duration: code.duration, periods: code.numberOfPeriods, prices: code.prices)
        json["id"] = .string(code.id)
        json["name"] = .string(code.name)
        json["active"] = .bool(code.isActive)
        json["customerEligibilities"] = .array(code.eligibilities.map { .string($0.rawValue) })
        json["offerEligibility"] = .string(code.offerEligibility.rawValue)
        if let autoRenews = code.autoRenews { json["autoRenew"] = .bool(autoRenews) }
        if let total = code.totalNumberOfCodes { json["totalNumberOfCodes"] = .int(total) }
        json["customCodes"] = .array(code.customCodes.map { custom in
            [
                "id": .string(custom.id), "code": .string(custom.code), "numberOfCodes": .int(custom.numberOfCodes),
                "expirationDate": custom.expirationDate.map(JSONValue.string) ?? .null, "active": .bool(custom.isActive),
            ]
        })
        json["oneTimeCodes"] = .array(code.oneTimeCodes.map { batch in
            [
                "id": .string(batch.id), "numberOfCodes": .int(batch.numberOfCodes),
                "expirationDate": batch.expirationDate.map(JSONValue.string) ?? .null, "active": .bool(batch.isActive),
                "environment": .string(batch.environment.rawValue),
            ]
        })
        return .object(json)
    }

    private static func terms(mode: OfferPaymentMode, duration: IntroductoryOfferDuration, periods: Int, prices: ExistingOfferPrices) -> [String: JSONValue] {
        let terms = OfferTerms(mode: mode, duration: duration, numberOfPeriods: periods, price: prices.usPrice)
        return [
            "mode": .string(mode.apiValue),
            "duration": .string(duration.rawValue),
            "numberOfPeriods": .int(periods),
            "priceUSD": prices.usPrice.map(MCPPriceValue.json) ?? .null,
            "territories": .array(prices.territoryIDs.map(JSONValue.string)),
            "summary": .string(terms.summary),
        ]
    }

    private static func queued(_ change: PendingChange) -> JSONValue {
        var json: [String: JSONValue] = [
            "changeId": .string(change.id),
            "kind": .string(SubscriptionOfferChanges.kind(of: change)?.rawValue ?? ""),
            "change": .string("\(change.title): \(change.newValue)"),
            "by": .string(change.source.title),
        ]
        if let blocked = change.blockingMessage { json["blockedReason"] = .string(blocked) }
        return .object(json)
    }
}
