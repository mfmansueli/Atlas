//
//  SubscriptionOfferPushError.swift
//  Atlas
//

import Foundation

/// Why a promotional offer, win-back offer or offer code (a subscription's
/// or an in-app purchase's) couldn't be created or priced.
enum SubscriptionOfferPushError: LocalizedError, Hashable, Sendable {
    /// The subscription isn't available anywhere yet.
    case notAvailable
    /// Apple has no price point at `price` in the territory (alpha-3).
    case noPricePoint(territoryID: String, price: Decimal, nearest: [Decimal])
    /// No territory it runs in has a price point for it.
    case noTerritories
    /// App Store Connect's answer to the create named no offer.
    case notCreated
    /// The in-app purchase isn't available anywhere yet.
    case inAppPurchaseNotAvailable
    /// Apple has no in-app purchase price point at `price` in the territory.
    case noInAppPurchasePricePoint(territoryID: String, price: Decimal, nearest: [Decimal])

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "The subscription isn’t available in any country or region yet. Set its availability, then push again.")
        case let .noPricePoint(territoryID, price, nearest):
            let (amount, name, suggestion) = Self.describe(price, in: territoryID, nearest: nearest)
            return String(localized: "Apple has no \(amount) price in \(name) for this subscription.\(suggestion)")
        case let .noInAppPurchasePricePoint(territoryID, price, nearest):
            let (amount, name, suggestion) = Self.describe(price, in: territoryID, nearest: nearest)
            return String(localized: "Apple has no \(amount) price in \(name) for this in-app purchase.\(suggestion)")
        case .inAppPurchaseNotAvailable:
            return String(localized: "The in-app purchase isn’t available in any country or region yet. Set its availability, then push again.")
        case .noTerritories:
            return String(localized: "Apple has no price for this offer in any country or region it runs in.")
        case .notCreated:
            return String(localized: "App Store Connect didn’t say which offer it created. Refresh Pricing before pushing again.")
        }
    }

    /// The price in the territory's currency, its name and " Try $1.99 or $2.99."
    private static func describe(_ price: Decimal, in territoryID: String, nearest: [Decimal]) -> (String, String, String) {
        let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
        let currency = CurrencyFormat.forCurrency(territory?.currencyCode ?? "USD")
        let options = nearest.map { currency.format($0) }.formatted(.list(type: .or))
        let suggestion = nearest.isEmpty ? "" : String(localized: " Try \(options).")
        return (currency.format(price), territory?.name ?? territoryID, suggestion)
    }
}
