//
//  OfferPricesPlan.swift
//  Atlas
//

import Foundation

/// Where an offer runs and what it costs, as a queued offer write carries
/// it under `atlas.offerPrices` until the push reads the price points: the
/// subscription (or in-app purchase) whose points it reads, the US price
/// (nil for a free subscription offer), the chosen territories (nil for
/// every one it's sold in) and the ones priced apart.
struct OfferPricesPlan: Hashable, Sendable {
    var owner: OfferPriceOwner
    var usPrice: Decimal?
    var territoryIDs: [String]?
    var territoryPrices: [String: Decimal] = [:]

    static let metaKey = "atlas"
    static let planKey = "offerPrices"

    var isFree: Bool { usPrice == nil }

    /// The subscription's (or in-app purchase's) ID.
    var subscriptionID: String { owner.id }

    init(owner: OfferPriceOwner, usPrice: Decimal?, territoryIDs: [String]?, territoryPrices: [String: Decimal] = [:]) {
        self.owner = owner
        self.usPrice = usPrice
        self.territoryIDs = territoryIDs
        self.territoryPrices = territoryPrices
    }

    init(subscriptionID: String, usPrice: Decimal?, territoryIDs: [String]?, territoryPrices: [String: Decimal] = [:]) {
        self.init(owner: .subscription(subscriptionID), usPrice: usPrice, territoryIDs: territoryIDs, territoryPrices: territoryPrices)
    }

    /// The plan for `terms` on `subscriptionID`.
    init(subscriptionID: String, terms: OfferTerms) {
        self.init(
            subscriptionID: subscriptionID,
            usPrice: terms.sentPrice,
            territoryIDs: terms.territories.chosenIDs,
            territoryPrices: terms.sentTerritoryPrices
        )
    }

    /// The plan a queued body carries; nil when it has none.
    init?(body: [String: Any]) {
        guard let plan = (body[Self.metaKey] as? [String: Any])?[Self.planKey] as? [String: Any] else { return nil }
        if let id = plan[OfferPriceOwner.subscription("").planKey] as? String {
            owner = .subscription(id)
        } else if let id = plan[OfferPriceOwner.inAppPurchase("").planKey] as? String {
            owner = .inAppPurchase(id)
        } else {
            return nil
        }
        usPrice = (plan["priceUSD"] as? String).flatMap(Self.decimal)
        territoryIDs = plan["territories"] as? [String]
        let prices = plan["territoryPrices"] as? [String: String] ?? [:]
        territoryPrices = prices.compactMapValues(Self.decimal)
    }

    /// `atlas.offerPrices` as JSON.
    var json: [String: Any] {
        var plan: [String: Any] = [owner.planKey: owner.id]
        if let usPrice { plan["priceUSD"] = Self.string(usPrice) }
        if let territoryIDs { plan["territories"] = territoryIDs }
        if !territoryPrices.isEmpty { plan["territoryPrices"] = territoryPrices.mapValues(Self.string) }
        return plan
    }

    /// The terms' price part back: mode and duration come from the body.
    func applied(to terms: OfferTerms) -> OfferTerms {
        var terms = terms
        terms.price = usPrice
        terms.territories = territoryIDs.map(IntroductoryOfferTerritories.chosen) ?? .everywhere
        terms.territoryPrices = territoryPrices
        return terms
    }

    static func decimal(_ text: String) -> Decimal? {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func string(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
