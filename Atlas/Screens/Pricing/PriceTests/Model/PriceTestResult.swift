//
//  PriceTestResult.swift
//  Atlas
//

import Foundation

/// What a price test did (board 76): the change in page view → start
/// conversion in the test's countries minus the change in the comparison
/// region's, with its 90% range, and the verdict.
struct PriceTestResult: Hashable, Sendable {
    var verdict: ResultVerdict
    /// Nil when too few to tell.
    var howSure: HowSure?
    /// The test's change minus the comparison's, in percentage points.
    var points: Double
    var low: Double
    var high: Double
    var windows: PriceTestWindows

    var hasComparison: Bool { windows.controlBefore != nil && windows.controlDuring != nil }

    /// The 90% range is on one side of zero.
    var excludesZero: Bool { low > 0 || high < 0 }

    /// "+1.8 points": the effect without its range (the card's line).
    var pointsText: String {
        String(localized: "\(PriceConfidenceText.points(points)) points", comment: "kind:label")
    }

    /// "+0.4 to +3.1 points" (Details).
    var rangeText: String {
        String(localized: "\(PriceConfidenceText.points(low)) to \(PriceConfidenceText.points(high)) points", comment: "kind:label")
    }
}
