//
//  MCPInAppPurchaseOfferCodesJSON.swift
//  Atlas
//

import Foundation

/// An in-app purchase's offer codes as get_subscriptions returns them, each
/// with every attribute App Store Connect has (name, customerEligibilities,
/// active, productionCodeCount, sandboxCodeCount), its territories, US
/// price, custom codes and one-time code batches, and the offer code
/// changes waiting in Review & Push.
enum MCPInAppPurchaseOfferCodesJSON {
    /// `offerCodes` and `queuedOffers` for one in-app purchase; the offer
    /// codes are "unknown" when they couldn't be read.
    static func fields(extras: PurchaseExtras?, queued: [PendingChange], purchasePrice: Decimal?) -> [String: JSONValue] {
        var json: [String: JSONValue] = ["queuedOffers": .array(queued.map(MCPSubscriptionOffersJSON.queued))]
        guard let extras, extras.offersRead else {
            json["offerCodes"] = "unknown"
            return json
        }
        json["offerCodes"] = .array(extras.inAppPurchaseOfferCodes.map { offerCode($0, purchasePrice: purchasePrice) })
        return json
    }

    static func offerCode(_ code: ExistingInAppPurchaseOfferCode, purchasePrice: Decimal?) -> JSONValue {
        var json: [String: JSONValue] = [
            "id": .string(code.id),
            "name": .string(code.name),
            "active": .bool(code.isActive),
            "customerEligibilities": .array(code.eligibilities.map { .string($0.rawValue) }),
            "priceUSD": code.prices.usPrice.map(MCPPriceValue.json) ?? .null,
            "territories": .array(code.prices.territoryIDs.map(JSONValue.string)),
            "summary": .string(code.terms.summary(purchasePrice: purchasePrice)),
        ]
        if let count = code.productionCodeCount { json["productionCodeCount"] = .int(count) }
        if let count = code.sandboxCodeCount { json["sandboxCodeCount"] = .int(count) }
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
}
