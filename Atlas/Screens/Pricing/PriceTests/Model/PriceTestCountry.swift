//
//  PriceTestCountry.swift
//  Atlas
//

import Foundation

/// One country of a price test: its price before and during the test, with
/// Apple's price point for each (nil while Apple's points aren't read).
struct PriceTestCountry: Identifiable, Hashable, Codable, Sendable {
    /// Alpha-3, e.g. "DEU".
    var territoryID: String
    var currencyCode: String
    var oldPrice: Decimal
    var testPrice: Decimal
    var oldPricePointID: String?
    var testPricePointID: String?

    var id: String { territoryID }

    var isRaise: Bool { testPrice > oldPrice }

    var change: PriceChange { PriceChange(old: oldPrice, new: testPrice) }

    var currency: CurrencyFormat { CurrencyFormat.forCurrency(currencyCode) }

    /// "Germany €39.99 → €31.99".
    func example(in catalog: TerritoryCatalog = .standard) -> String {
        let name = catalog.territory(alpha3: territoryID)?.name ?? territoryID
        return "\(name) \(currency.format(oldPrice)) → \(currency.format(testPrice))"
    }
}
