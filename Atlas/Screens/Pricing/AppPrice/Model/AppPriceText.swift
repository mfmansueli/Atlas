//
//  AppPriceText.swift
//  Atlas
//

import Foundation

/// How the app's price reads in Pricing, Review & Push and the MCP tools.
enum AppPriceText {
    /// "Free" for 0, else the amount in the currency: "$2.99", "R$ 14,90".
    static func price(_ amount: Decimal, currencyCode: String) -> String {
        amount == 0 ? String(localized: "Free") : CurrencyFormat.forCurrency(currencyCode).format(amount)
    }

    /// "$2.99 in the United States".
    static func price(_ amount: Decimal, in territory: AppTerritory) -> String {
        let price = price(amount, currencyCode: territory.currencyCode)
        return amount == 0 ? price : String(localized: "\(price) in \(territory.name)")
    }

    /// What the change sets: "Free everywhere" or "$2.99 in the United
    /// States · equalized everywhere else".
    static func newPrice(_ amount: Decimal, in territory: AppTerritory) -> String {
        guard amount != 0 else { return String(localized: "Free everywhere") }
        return String(localized: "\(price(amount, in: territory)) · equalized everywhere else")
    }

    /// "Proceeds $2.54", Apple's own figure for the point.
    static func proceeds(_ amount: Decimal, currencyCode: String) -> String {
        String(localized: "Proceeds \(CurrencyFormat.forCurrency(currencyCode).format(amount))")
    }
}
