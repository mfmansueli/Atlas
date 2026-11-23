//
//  SubscriptionOfferPushError.swift
//  Atlas
//

import Foundation

/// Why a promotional offer, win-back offer or offer code couldn't be
/// created or priced.
enum SubscriptionOfferPushError: LocalizedError, Hashable, Sendable {
    /// The subscription isn't available anywhere yet.
    case notAvailable
    /// Apple has no price point at `price` in the territory (alpha-3).
    case noPricePoint(territoryID: String, price: Decimal, nearest: [Decimal])
    /// No territory it runs in has a price point for it.
    case noTerritories
    /// App Store Connect's answer to the create named no offer.
    case notCreated

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "The subscription isn’t available in any country or region yet. Set its availability, then push again.")
        case let .noPricePoint(territoryID, price, nearest):
            let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
            let currency = CurrencyFormat.forCurrency(territory?.currencyCode ?? "USD")
            let options = nearest.map { currency.format($0) }.formatted(.list(type: .or))
            let suggestion = nearest.isEmpty ? "" : String(localized: " Try \(options).")
            let name = territory?.name ?? territoryID
            return String(localized: "Apple has no \(currency.format(price)) price in \(name) for this subscription.\(suggestion)")
        case .noTerritories:
            return String(localized: "Apple has no price for this offer in any country or region it runs in.")
        case .notCreated:
            return String(localized: "App Store Connect didn’t say which offer it created. Refresh Pricing before pushing again.")
        }
    }
}
