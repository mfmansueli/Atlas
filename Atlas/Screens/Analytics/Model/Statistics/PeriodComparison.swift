//
//  PeriodComparison.swift
//  Atlas
//

import Foundation

/// A rate in one period against the same rate in another.
struct PeriodComparison: Hashable, Sendable {
    var outcome: ComparisonOutcome
    /// The difference in percentage points; nil when too few.
    var points: Double?
    /// The test's z-score: negative when the rate fell.
    var zScore: Double

    static let tooFew = PeriodComparison(outcome: .tooFew, points: nil, zScore: 0)

    /// "+0.4 pt", "−1.2 pt", or "" when too few.
    var pointsText: String {
        points.map(AnalyticsText.points) ?? ""
    }
}
