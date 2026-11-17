//
//  ChangeResult.swift
//  Atlas
//

import Foundation

/// A change's before and after on the step it should move.
struct ChangeResult: Hashable, Sendable {
    /// One step's two sides.
    struct Side: Hashable, Sendable {
        var title: String
        var before: AnalyticsRate
        var after: AnalyticsRate
        var comparison: PeriodComparison
    }

    enum State: Hashable, Sendable {
        /// 28 days have passed.
        case final
        /// Day `day` of 28; final on `ends`.
        case measuring(day: Int, ends: Date)
        /// Apple's data doesn't reach back before the change.
        case noBefore
    }

    var change: MeasuredChange
    var state: State
    var before: AnalyticsPeriod
    var after: AnalyticsPeriod
    var main: Side
    var others: [Side]

    var isTooFew: Bool { main.comparison.outcome == .tooFew }

    /// The pill in the list: "Better · sure", "Day 20 of 28"…
    var statusText: String {
        switch state {
        case let .measuring(day, _): String(localized: "Day \(day) of \(ResultsEvaluator.windowDays)")
        case .noBefore: String(localized: "No data before it")
        case .final: main.comparison.outcome.verdict
        }
    }

    /// "1.9% → 2.3%".
    var beforeAfterText: String { "\(main.before.text) → \(main.after.text)" }
}
