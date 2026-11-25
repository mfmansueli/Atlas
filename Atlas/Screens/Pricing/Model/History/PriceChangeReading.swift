//
//  PriceChangeReading.swift
//  Atlas
//

import Foundation

/// One territory's price as a read of App Store Connect found it.
struct PriceChangeReading: Hashable, Sendable {
    var price: Decimal
    var currencyCode: String
    /// Apple's start date of the price in effect, when the API gives one.
    var startDate: Date?
}
