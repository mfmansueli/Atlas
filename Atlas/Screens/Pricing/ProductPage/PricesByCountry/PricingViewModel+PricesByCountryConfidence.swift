//
//  PricingViewModel+PricesByCountryConfidence.swift
//  Atlas
//

import Foundation

// How sure Prices by Country's suggestions are, and what they stand on
// (Phases 3 and 5): the banner's level weighted by traffic, its second
// line per sales state, and the summary line when nothing is suggested.
extension PricingViewModel {
    /// The banner's how sure, weighted by the open suggestions' 90-day
    /// page views (`HowSureWeighting`).
    func countriesHowSure(productID: String) -> HowSure {
        let rows = (countryRows(productID: productID) ?? []).filter(\.hasSuggestion)
        return HowSureWeighting.level(rows.map { row in
            HowSureWeighting.Entry(level: row.confidence?.howSure ?? .notVerySure, pageViews: row.pageViews ?? 0)
        })
    }

    /// The banner's second line, by the product's sales state.
    func countriesBaseline(productID: String) -> String {
        guard let matrix = countriesMatrix(productID: productID) else {
            return PricingSalesLine.banner(availability: .notRead, salesCountries: 0)
        }
        let sales = matrix.sheet.sales
        let salesCountries = sales.signals.values.count { $0.starts > 0 }
        let borrowed = (countryRows(productID: productID) ?? []).count { $0.hasSuggestion && $0.evidence?.borrowedFrom != nil }
        return PricingSalesLine.banner(availability: sales.availability, salesCountries: salesCountries, borrowedCountries: borrowed)
    }

    /// With suggestions on and none to make: "Your prices match local
    /// purchasing power in 175 countries.", counting the countries whose
    /// suggestion is today's price. Nil while anything is suggested, open
    /// or dismissed, and for an in-app purchase.
    func countriesMatchLine(productID: String) -> String? {
        guard let matrix = countriesMatrix(productID: productID), matrix.showsSuggestions, !matrix.product.isInAppPurchase,
              let rows = countryRows(productID: productID), !rows.contains(where: { $0.suggested != nil })
        else { return nil }
        let matching = matrix.rows.count { !$0.isBase && $0.recommendation?.isUnchanged == true }
        return PricesByCountryMatchLine.text(count: matching)
    }
}
