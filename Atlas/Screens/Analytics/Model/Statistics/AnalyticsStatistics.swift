//
//  AnalyticsStatistics.swift
//  Atlas
//

import Foundation

/// The one place rates, ranges and verdicts are computed, so Funnel, Break
/// It Down, Subscriptions and After Changes always agree.
enum AnalyticsStatistics {
    /// z for a 90% two-sided range.
    static let z90 = 1.645
    /// z beyond which a difference is "sure" (99%).
    static let z99 = 2.58
    /// A rate needs this many in the step before…
    static let minimumTotal = 30
    /// …and this many in the step itself.
    static let minimumCount = 3
    /// A change between two periods needs this many in the step before…
    static let minimumComparedTotal = 100
    /// …and this many in the step itself, on both sides.
    static let minimumComparedCount = 5

    /// The Wilson score interval of `count` out of `total` at 90%.
    static func wilson(count: Int, total: Int) -> WilsonInterval {
        guard total > 0 else { return .zero }
        let size = Double(total)
        let share = Double(count) / size
        let score = z90
        let denominator = 1 + score * score / size
        let center = (share + score * score / (2 * size)) / denominator
        let half = score * (share * (1 - share) / size + score * score / (4 * size * size)).squareRoot() / denominator
        return WilsonInterval(low: max(0, center - half), high: min(1, center + half), value: share, halfWidth: half)
    }

    /// `count` of `total` as a rate, against `average` when there is one.
    static func rate(count: Int?, total: Int?, average: Double? = nil) -> AnalyticsRate {
        guard let count, let total else { return .missing }
        guard total >= minimumTotal, count >= minimumCount else { return .tooFew(count: count, total: total) }
        let interval = wilson(count: count, total: total)
        let standing: RateStanding? = average.map { average in
            if interval.low > average { return .better }
            if interval.high < average { return .worse }
            return .same
        }
        let relative = interval.halfWidth / max(interval.value, 1e-6)
        let bars = relative < 0.12 ? 3 : relative < 0.3 ? 2 : 1
        return .measured(MeasuredRate(
            count: count, total: total, value: interval.value, low: interval.low, high: interval.high, standing: standing, bars: bars
        ))
    }

    /// A period's rate against an earlier period's (pooled two-proportion
    /// z-test): "sure" beyond 99%, "fairly sure" beyond 90%.
    static func compare(count: Int?, total: Int?, previousCount: Int?, previousTotal: Int?) -> PeriodComparison {
        guard let count, let total, let previousCount, let previousTotal,
              total >= minimumComparedTotal, previousTotal >= minimumComparedTotal,
              count >= minimumComparedCount, previousCount >= minimumComparedCount
        else { return .tooFew }
        let now = Double(count) / Double(total)
        let before = Double(previousCount) / Double(previousTotal)
        let pooled = Double(count + previousCount) / Double(total + previousTotal)
        let variance = pooled * (1 - pooled) * (1 / Double(total) + 1 / Double(previousTotal))
        let score = variance > 0 ? (now - before) / variance.squareRoot() : 0
        let confidence: ComparisonConfidence? = abs(score) > z99 ? .sure : abs(score) > z90 ? .fairlySure : nil
        var outcome = ComparisonOutcome.same
        if let confidence {
            if now > before { outcome = .higher(confidence) } else { outcome = .lower(confidence) }
        }
        return PeriodComparison(outcome: outcome, points: (now - before) * 100, zScore: score)
    }
}
