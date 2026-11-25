//
//  PriceTestCandidate.swift
//  Atlas
//

import Foundation

/// One country a price test could move: today's price, Apple's price
/// points there (for rounding), the suggested purchasing-power price, and
/// its last 28 days.
struct PriceTestCandidate: Sendable {
    var territory: Territory
    var current: PricePoint
    var ladder: PricePointLadder?
    /// The suggestion's price; nil when the country has none.
    var suggested: PricePoint?
    var recent: SalesSignal?
}
