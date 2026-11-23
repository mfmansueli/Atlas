//
//  OfferTermsDraft.swift
//  Atlas
//

import Foundation

/// An offer's terms as its sheet holds them while they're typed: the price
/// fields' text, the territory choice and the territories priced apart.
struct OfferTermsDraft: Hashable, Sendable {
    var mode = OfferPaymentMode.freeTrial
    var duration = IntroductoryOfferDuration.oneWeek
    var numberOfPeriods = 1
    var priceText = ""
    var choosesTerritories = false
    var chosen: Set<String> = [NewSubscription.baseTerritoryID]
    /// Territory (alpha-3) → its price, typed in its own currency.
    var territoryPriceTexts: [String: String] = [:]

    init() {}

    /// The draft for terms a sheet starts from, e.g. an offer App Store
    /// Connect has.
    init(_ terms: OfferTerms) {
        mode = terms.mode
        duration = terms.duration
        numberOfPeriods = terms.numberOfPeriods
        priceText = terms.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        if let ids = terms.territories.chosenIDs {
            choosesTerritories = true
            chosen = Set(ids)
        }
        territoryPriceTexts = terms.territoryPrices.mapValues { NSDecimalNumber(decimal: $0).stringValue }
    }

    /// The form as terms; prices that aren't numbers count as missing, so
    /// the checks name them.
    var terms: OfferTerms {
        var terms = OfferTerms(mode: mode, duration: duration, numberOfPeriods: numberOfPeriods)
        terms.price = mode == .freeTrial ? nil : NewSubscription.price(from: priceText)
        terms.territories = choosesTerritories ? .chosen(chosen.sorted()) : .everywhere
        if mode != .freeTrial {
            terms.territoryPrices = territoryPriceTexts.mapValues { NewSubscription.price(from: $0) ?? 0 }
        }
        return terms
    }

    /// A duration the mode allows for a subscription billed each `period`,
    /// and periods in its range.
    mutating func fit(period: SubscriptionPeriod) {
        let durations = mode.allowedDurations(for: period)
        if !durations.contains(duration), let first = durations.first { duration = first }
        let range = mode.allowedPeriods(for: period)
        numberOfPeriods = min(max(numberOfPeriods, range.lowerBound), range.upperBound)
    }
}
