//
//  PriceResultsEntry.swift
//  Atlas
//

import Foundation

/// One territory's price change that Results compares: from a push, whose
/// old price Restore can put back, or read from App Store Connect.
struct PriceResultsEntry: Hashable, Sendable {
    /// Alpha-3.
    var territoryID: String
    var oldPrice: Decimal
    var newPrice: Decimal
    /// The pushed change, for Restore; nil for a change read from App Store
    /// Connect.
    var pushed: PendingChange?
}
