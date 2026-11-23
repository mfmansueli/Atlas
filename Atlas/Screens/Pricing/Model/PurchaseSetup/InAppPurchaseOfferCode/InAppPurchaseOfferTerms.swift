//
//  InAppPurchaseOfferTerms.swift
//  Atlas
//

import Foundation

/// What an in-app purchase's offer code costs and where: its price in the
/// United States in US dollars (zero makes it free), the countries or
/// regions it runs in, and any of them priced apart in their own currency.
/// Every other territory gets the price Apple equalizes with the US one
/// when it's pushed (`OfferPriceReader` with the purchase's price points).
/// Unlike a subscription's, it has no mode or duration: it's one purchase.
struct InAppPurchaseOfferTerms: Hashable, Sendable {
    /// What it costs in the United States; zero for free, nil while missing.
    var price: Decimal?
    var territories: IntroductoryOfferTerritories = .everywhere
    /// Territories (alpha-3) priced apart, e.g. ["BRA": 9.90]. Paid only.
    var territoryPrices: [String: Decimal] = [:]

    var isFree: Bool { price == 0 }

    /// The prices set apart a push sends: none for a free code.
    var sentTerritoryPrices: [String: Decimal] {
        isFree ? [:] : territoryPrices
    }

    /// What the push reads the points from for the purchase `purchaseID`.
    func plan(purchaseID: String) -> OfferPricesPlan {
        OfferPricesPlan(
            owner: .inAppPurchase(purchaseID), usPrice: price ?? 0,
            territoryIDs: territories.chosenIDs, territoryPrices: sentTerritoryPrices
        )
    }

    /// The terms a queued plan carries.
    init(plan: OfferPricesPlan) {
        price = plan.usPrice
        territories = plan.territoryIDs.map(IntroductoryOfferTerritories.chosen) ?? .everywhere
        territoryPrices = plan.territoryPrices
    }

    init(price: Decimal?, territories: IntroductoryOfferTerritories = .everywhere, territoryPrices: [String: Decimal] = [:]) {
        self.price = price
        self.territories = territories
        self.territoryPrices = territoryPrices
    }

    /// "Free", "$1.99".
    var summary: String {
        guard let price else { return String(localized: "No price yet") }
        return price == 0 ? String(localized: "Free") : CurrencyFormat.forCurrency("USD").format(price)
    }

    /// "$1.99 instead of $4.99", "Free instead of $4.99".
    func summary(purchasePrice: Decimal?) -> String {
        guard let purchasePrice, purchasePrice > 0, price != nil else { return summary }
        return String(localized: "\(summary) instead of \(CurrencyFormat.forCurrency("USD").format(purchasePrice))")
    }

    /// "Free everywhere", "$0.99 in the United States · equalized everywhere
    /// else · Brazil R$ 4,90".
    var pricesTitle: String {
        guard let price else { return summary }
        guard price > 0 else { return String(localized: "Free everywhere it runs") }
        var parts = [
            String(localized: "\(CurrencyFormat.forCurrency("USD").format(price)) in the United States"),
            String(localized: "equalized everywhere else"),
        ]
        for (territoryID, price) in territoryPrices.sorted(by: { $0.key < $1.key }) {
            let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
            let currency = CurrencyFormat.forCurrency(territory?.currencyCode ?? "USD")
            parts.append("\(territory?.name ?? territoryID) \(currency.format(price))")
        }
        return parts.joined(separator: " · ")
    }

    /// The share of the purchase's price a customer pays, for the Offers
    /// tab: zero for a free code or without a price.
    func priceShare(of purchasePrice: Decimal?) -> Decimal {
        guard let price, let purchasePrice, purchasePrice > 0 else { return 0 }
        return price / purchasePrice
    }

    /// Whether App Store Connect takes `price` as an offer code's: zero or
    /// more, below 100,000, with up to two decimals.
    static func isValidPrice(_ price: Decimal) -> Bool {
        price >= 0 && price < 100_000 && price.rounded(scale: 2) == price
    }

    /// Everything App Store Connect would refuse in the terms, in the form's
    /// order. `purchasePrice` is the in-app purchase's own US price, when
    /// it has one: the code's is below it.
    func problems(purchasePrice: Decimal?) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        if let price {
            if !Self.isValidPrice(price) {
                problems.append(.invalidInAppPurchaseOfferPrice)
            } else if let purchasePrice, price >= purchasePrice {
                problems.append(.notBelowPurchasePrice(CurrencyFormat.forCurrency("USD").format(purchasePrice)))
            }
        } else {
            problems.append(.terms(.missingPrice))
        }
        if let chosen = territories.chosenIDs {
            if chosen.isEmpty { problems.append(.terms(.noTerritories)) }
            let unknown = chosen.filter { TerritoryCatalog.standard.territory(alpha3: $0) == nil }
            if !unknown.isEmpty { problems.append(.terms(.unknownTerritories(unknown))) }
        }
        return problems + territoryPriceProblems
    }

    private var territoryPriceProblems: [SubscriptionOfferProblem] {
        guard !isFree, !territoryPrices.isEmpty else { return [] }
        var problems: [SubscriptionOfferProblem] = []
        if territoryPrices[NewSubscription.baseTerritoryID] != nil { problems.append(.basePriceSetApart) }
        let unknown = territoryPrices.keys.filter { TerritoryCatalog.standard.territory(alpha3: $0) == nil }.sorted()
        if !unknown.isEmpty { problems.append(.terms(.unknownTerritories(unknown))) }
        if let chosen = territories.chosenIDs {
            let outside = territoryPrices.keys.filter { !chosen.contains($0) && $0 != NewSubscription.baseTerritoryID }.sorted()
            if !outside.isEmpty { problems.append(.pricedOutsideTerritories(outside)) }
        }
        let invalid = territoryPrices.filter { !NewSubscription.isValidPrice($0.value) }.keys.sorted()
        if !invalid.isEmpty { problems.append(.invalidTerritoryPrices(invalid)) }
        return problems
    }
}
