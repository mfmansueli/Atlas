//
//  TerritoryPriceContext.swift
//  Atlas
//

import Foundation

/// One territory's price of the app's main subscription against what its
/// purchasing power suggests.
struct TerritoryPriceContext: Hashable, Sendable {
    /// "R$ 249,90".
    var priceText: String
    /// The purchasing-power price, "R$ 104".
    var suggestedText: String
    /// Price ÷ purchasing-power price: 2.4 means 2.4× too high.
    var ratio: Double
    var productName: String
}
