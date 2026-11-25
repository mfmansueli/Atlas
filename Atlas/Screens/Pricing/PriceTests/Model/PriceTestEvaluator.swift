//
//  PriceTestEvaluator.swift
//  Atlas
//

import Foundation

/// The verdict of a finished price test: the test countries' change in
/// conversion against the comparison region's over the same 28 days
/// (difference in differences), at 90% as Results' verdicts are; Sure
/// beyond 99%. Without a comparison it's before against during, and never
/// more than Fairly sure. Proceeds can only hold a verdict back, as in
/// `ResultsEvaluator`.
enum PriceTestEvaluator {
    static func result(_ windows: PriceTestWindows) -> PriceTestResult {
        let control = windows.controlBefore.flatMap { before in windows.controlDuring.map { (before, $0) } }
        var sides = [windows.testBefore, windows.testDuring]
        if let control { sides += [control.0, control.1] }
        let testChange = rate(windows.testDuring) - rate(windows.testBefore)
        let controlChange = control.map { rate($0.1) - rate($0.0) } ?? 0
        let effect = testChange - controlChange
        let error = sides.map(variance).reduce(0, +).squareRoot()
        let half = AnalyticsStatistics.z90 * error
        let tooFew = PriceTestResult(
            verdict: .tooLittleData, howSure: nil, points: effect * 100, low: (effect - half) * 100, high: (effect + half) * 100, windows: windows
        )
        guard sides.allSatisfy(PriceTestRules.isEnough), error > 0 else { return tooFew }
        let score = effect / error
        let proceeds = proceedsChange(windows)
        let verdict: ResultVerdict = if abs(score) <= AnalyticsStatistics.z90 {
            .aboutTheSame
        } else if effect > 0 {
            proceeds >= 0 ? .better : .aboutTheSame
        } else {
            proceeds <= 0 ? .worse : .aboutTheSame
        }
        var howSure: HowSure = abs(score) > AnalyticsStatistics.z99 ? .sure : abs(score) > AnalyticsStatistics.z90 ? .fairlySure : .notVerySure
        // "About the same" within a point either way is fairly sure too.
        if verdict == .aboutTheSame, abs(score) <= AnalyticsStatistics.z90, half * 100 <= 1 { howSure = .fairlySure }
        if control == nil, howSure == .sure { howSure = .fairlySure }
        return PriceTestResult(
            verdict: verdict, howSure: howSure, points: effect * 100, low: (effect - half) * 100, high: (effect + half) * 100, windows: windows
        )
    }

    /// Proceeds during the test against what the comparison's change says
    /// they'd have been without it.
    static func proceedsChange(_ windows: PriceTestWindows) -> Decimal {
        var expected = windows.testBefore.proceeds
        if let before = windows.controlBefore, let during = windows.controlDuring, before.proceeds > 0 {
            expected = windows.testBefore.proceeds * during.proceeds / before.proceeds
        }
        return windows.testDuring.proceeds - expected
    }

    private static func rate(_ signal: SalesSignal) -> Double {
        signal.conversion ?? 0
    }

    private static func variance(_ signal: SalesSignal) -> Double {
        guard signal.pageViews > 0 else { return 0 }
        let share = min(max(rate(signal), 0), 1)
        return share * (1 - share) / Double(signal.pageViews)
    }
}
