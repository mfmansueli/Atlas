//
//  PriceTestEnding.swift
//  Atlas
//

import Foundation

/// A running test being ended: End Test Early… from the card's menu, or a
/// new price in one of its countries (End Test and Set…).
struct PriceTestEnding: Hashable, Sendable {
    var testID: PriceTest.ID
    /// End Test and Set: the country and its new price; nil ends early.
    var territoryID: String?
    var price: Decimal?

    var setsPrice: Bool { territoryID != nil && price != nil }
}
