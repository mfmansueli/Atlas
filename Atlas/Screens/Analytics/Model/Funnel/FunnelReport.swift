//
//  FunnelReport.swift
//  Atlas
//

import Foundation

/// The Funnel view's content for one app and period.
struct FunnelReport: Hashable, Sendable {
    /// Days asked for: 7, 28 or 90.
    var days: Int
    var period: AnalyticsPeriod
    /// nil when the app has less than two periods of data.
    var previous: AnalyticsPeriod?
    /// Less than one full period of data: counts and rates, no verdicts.
    var isNew: Bool
    var steps: [FunnelStep]
    var totals: FunnelTotals
    var previousTotals: FunnelTotals?
    var callout: FunnelCallout
    /// The line under the funnel about what's missing or how to read it.
    var note: String?
    var noteIsWarning = false

    func step(_ stage: FunnelStage) -> FunnelStep? {
        steps.first { $0.stage == stage }
    }

    /// The step whose rate fell most surely against the previous period.
    var worstStep: FunnelStep? {
        steps
            .filter { ($0.comparison?.zScore ?? 0) < -AnalyticsStatistics.z90 }
            .min { ($0.comparison?.zScore ?? 0) < ($1.comparison?.zScore ?? 0) }
    }

    /// "Oct 13–Nov 9 · compared with Sep 15–Oct 12".
    var rangeText: String {
        guard let previous else { return String(localized: "\(period.text) · no earlier period to compare yet") }
        return String(localized: "\(period.text) · compared with \(previous.text)")
    }
}
