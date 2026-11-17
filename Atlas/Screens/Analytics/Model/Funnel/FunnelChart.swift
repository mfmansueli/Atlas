//
//  FunnelChart.swift
//  Atlas
//

import Foundation

/// The funnel's timeline for one step: the current period after the
/// previous one, the long-run average, and what was pushed meanwhile.
struct FunnelChart: Hashable, Sendable {
    var stage: FunnelStage
    /// The previous period's days, then the current one's.
    var points: [FunnelChartPoint]
    /// Where the current period begins in `points`; 0 without a previous one.
    var currentStart: Int
    /// The rate over everything kept; nil for impressions or too little data.
    var average: Double?
    var marks: [MeasuredChange]
    /// Why there's no line.
    var gap: FunnelGap?

    var isCount: Bool { stage == .impressions }
    var title: String { isCount ? stage.rateTitle : String(localized: "\(stage.rateTitle), daily") }
    var hasPrevious: Bool { currentStart > 0 }
    var isEmpty: Bool { gap != nil || points.allSatisfy { $0.value == nil } }

    var maximum: Double {
        let top = max(points.compactMap(\.value).max() ?? 0, average ?? 0)
        return top > 0 ? top * 1.15 : 1
    }

    /// Rates start a little under their lowest day, so a small move shows;
    /// counts start at zero.
    var minimum: Double {
        guard !isCount else { return 0 }
        let low = min(points.compactMap(\.value).min() ?? 0, average ?? .infinity)
        return low * 0.8
    }

    func text(_ value: Double) -> String {
        isCount ? AnalyticsText.count(Int(value.rounded())) : AnalyticsText.percent(value)
    }

    /// "Page views per impression over 56 days, from 5.1% to 6.3%."
    var accessibilityText: String {
        let values = points.compactMap(\.value)
        guard let low = values.min(), let high = values.max() else { return gap?.chartText ?? title }
        return String(localized: "\(title) over \(points.count) days, from \(text(low)) to \(text(high)).")
    }
}
