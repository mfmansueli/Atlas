//
//  PriceLevelMethod.swift
//  Atlas
//

import Foundation

/// How a territory's index value was obtained, as
/// `scripts/price-index/fetch_price_index.py` writes it.
enum PriceLevelMethod: String, Codable, Hashable, Sendable {
    /// The source's own figure for the edition's data year (World Bank:
    /// PPP ÷ market rate of that year, which is the price level ratio).
    case exact
    /// An older year (at most two), or the same ratio through another series
    /// (IMF: GDP in dollars ÷ GDP at PPP), where the exact figure is missing.
    case fallback
}
