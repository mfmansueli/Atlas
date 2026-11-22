//
//  InAppPurchasePriceError.swift
//  Atlas
//

import Foundation

/// Why a new in-app purchase's price couldn't be set.
enum InAppPurchasePriceError: LocalizedError, Hashable, Sendable {
    /// Apple has no price point at that price in the territory.
    case noPricePoint(price: Decimal, territoryID: String, nearest: [Decimal])

    var errorDescription: String? {
        switch self {
        case let .noPricePoint(price, territoryID, nearest):
            let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
            let currency = CurrencyFormat.forCurrency(territory?.currencyCode ?? "USD")
            let options = nearest.map { currency.format($0) }.formatted(.list(type: .or))
            let suggestion = nearest.isEmpty ? "" : String(localized: " Try \(options).")
            return String(localized: """
            Apple has no \(currency.format(price)) price in \(territory?.name ?? territoryID).\(suggestion) Set the price in App \
            Store Connect, or propose the purchase again with one of those.
            """)
        }
    }
}
