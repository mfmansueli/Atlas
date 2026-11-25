//
//  PriceChangeKnownPrice.swift
//  Atlas
//

import Foundation

/// The last price Atlas read for one product in one territory, so the next
/// read can tell a change made outside Atlas.
struct PriceChangeKnownPrice: Hashable, Codable, Sendable {
    var price: Decimal
    var currencyCode: String
    var readOn: Date
}
