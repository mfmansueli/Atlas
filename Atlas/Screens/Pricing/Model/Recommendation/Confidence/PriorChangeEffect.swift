//
//  PriorChangeEffect.swift
//  Atlas
//

import Foundation

/// What an earlier price change did to conversion (page view → start), in
/// percentage points, with its 90% range.
struct PriorChangeEffect: Hashable, Sendable {
    var before: SalesSignal
    var after: SalesSignal
    /// After's conversion minus before's, in points.
    var points: Double
    /// The 90% range of `points`.
    var low: Double
    var high: Double

    /// The whole range is on one side of zero; touching zero doesn't count.
    var excludesZero: Bool { low > 0 || high < 0 }
}

extension PriorChangeEffect {
    /// Newcombe's hybrid score interval for a difference of two
    /// proportions, from each side's 90% Wilson interval
    /// (`AnalyticsStatistics.wilson`). Nil without page views on a side.
    init?(before: SalesSignal, after: SalesSignal) {
        guard before.pageViews > 0, after.pageViews > 0 else { return nil }
        let first = AnalyticsStatistics.wilson(count: min(max(0, before.starts), before.pageViews), total: before.pageViews)
        let second = AnalyticsStatistics.wilson(count: min(max(0, after.starts), after.pageViews), total: after.pageViews)
        let difference = second.value - first.value
        let below = ((second.value - second.low) * (second.value - second.low) + (first.high - first.value) * (first.high - first.value)).squareRoot()
        let above = ((second.high - second.value) * (second.high - second.value) + (first.value - first.low) * (first.value - first.low)).squareRoot()
        self.init(before: before, after: after, points: difference * 100, low: (difference - below) * 100, high: (difference + above) * 100)
    }
}
