//
//  OfferTerms.swift
//  Atlas
//

import Foundation

/// What a promotional offer, win-back offer or offer code gives and where:
/// a free trial, or a lower price per period (pay as you go) or once (pay
/// up front), its US price in US dollars, the countries or regions it runs
/// in and any of them priced apart. Every other territory gets the price
/// Apple equalizes with the US one when it's pushed (`OfferPriceReader`),
/// the same machinery as an introductory offer's.
struct OfferTerms: Hashable, Sendable {
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var numberOfPeriods = 1
    /// What a paid offer costs in the United States, in US dollars: per
    /// period for pay as you go, once for pay up front. Nil for a free trial.
    var price: Decimal?
    var territories: IntroductoryOfferTerritories = .everywhere
    /// Territories (alpha-3) priced apart from the equalized price, in
    /// their own currency, e.g. ["BRA": 4.90]. Paid offers only.
    var territoryPrices: [String: Decimal] = [:]

    /// The attributes' `numberOfPeriods`: one for a free trial or pay up
    /// front offer.
    var sentPeriods: Int {
        mode == .payAsYouGo ? numberOfPeriods : 1
    }

    /// The price a push sends: none for a free trial.
    var sentPrice: Decimal? {
        mode == .freeTrial ? nil : price
    }

    /// The prices set apart that a push sends: none for a free trial.
    var sentTerritoryPrices: [String: Decimal] {
        mode == .freeTrial ? [:] : territoryPrices
    }

    /// The terms as an introductory offer's, for their summary and checks.
    var asIntroductory: NewIntroductoryOffer {
        NewIntroductoryOffer(mode: mode, duration: duration, numberOfPeriods: numberOfPeriods, price: sentPrice, territories: territories)
    }

    /// "Free for 1 week", "$0.99 a month for 3 × 1 month", "$4.99 for 3 months".
    var summary: String {
        asIntroductory.summary
    }

    /// "1 week", "3 × 1 month".
    var durationTitle: String {
        mode == .payAsYouGo && numberOfPeriods > 1 ? String(localized: "\(numberOfPeriods) × \(duration.title)") : duration.title
    }

    /// "$0.99 in the United States · equalized everywhere else · Brazil R$ 4,90";
    /// nil for a free trial.
    var pricesTitle: String? {
        guard let formatted = asIntroductory.formattedPrice else { return nil }
        var parts = [String(localized: "\(formatted) in the United States"), String(localized: "equalized everywhere else")]
        for (territoryID, price) in territoryPrices.sorted(by: { $0.key < $1.key }) {
            let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
            let currency = CurrencyFormat.forCurrency(territory?.currencyCode ?? "USD")
            parts.append("\(territory?.name ?? territoryID) \(currency.format(price))")
        }
        return parts.joined(separator: " · ")
    }

    /// The share of `subscriptionPrice` a customer pays, for the Offers
    /// tab's derived prices: zero for a free trial or without prices.
    func priceShare(of subscriptionPrice: Decimal?) -> Decimal {
        guard let price = sentPrice, let subscriptionPrice, subscriptionPrice > 0 else { return 0 }
        return price / subscriptionPrice
    }

    /// Everything App Store Connect would refuse in the terms, in the form's
    /// order. `period` is the subscription's billing period and
    /// `subscriptionPrice` its US price, when it has one.
    func problems(period: SubscriptionPeriod, subscriptionPrice: Decimal?) -> [SubscriptionOfferProblem] {
        var problems = asIntroductory.problems(period: period, subscriptionPrice: subscriptionPrice).map(SubscriptionOfferProblem.terms)
        guard mode != .freeTrial, !territoryPrices.isEmpty else { return problems }
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
