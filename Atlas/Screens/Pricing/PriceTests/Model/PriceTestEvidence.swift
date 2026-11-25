//
//  PriceTestEvidence.swift
//  Atlas
//

import Foundation

/// A finished price test as HowSure reads it: a measured change for every
/// country of its region, so their suggestions can be Sure
/// (`PriceConfidenceRule`).
struct PriceTestEvidence: Hashable, Sendable {
    var region: TerritoryRegion
    var endedOn: Date
    /// The test countries' 28 days before and during.
    var before: SalesSignal
    var during: SalesSignal
    /// The effect against the comparison, in points, with its 90% range.
    var points: Double
    var low: Double
    var high: Double

    var excludesZero: Bool { low > 0 || high < 0 }

    var effect: PriorChangeEffect {
        PriorChangeEffect(before: before, after: during, points: points, low: low, high: high)
    }

    init(region: TerritoryRegion, endedOn: Date, before: SalesSignal, during: SalesSignal, points: Double, low: Double, high: Double) {
        self.region = region
        self.endedOn = endedOn
        self.before = before
        self.during = during
        self.points = points
        self.low = low
        self.high = high
    }

    /// A test with its 28 days read; nil before.
    init?(_ test: PriceTest) {
        guard let result = test.result, let endsOn = test.endsOn else { return nil }
        self.init(
            region: test.region, endedOn: endsOn, before: result.windows.testBefore, during: result.windows.testDuring,
            points: result.points, low: result.low, high: result.high
        )
    }
}
