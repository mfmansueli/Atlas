//
//  ChangeChart.swift
//  Atlas
//

import Foundation

/// After Changes' chart (board 92): the step a push should move, day by
/// day, over the 28 days before it and the days after, counted the way its
/// result is (search only for search text, the languages it changed).
struct ChangeChart: Hashable, Sendable {
    var stage: FunnelStage
    var points: [FunnelChartPoint]
    var changeDay: AnalyticsDay
    /// Where the days after the push start in `points`.
    var afterStart: Int

    var title: String { String(localized: "\(stage.rateTitle), daily", comment: "kind:title · After Changes chart") }
    var isEmpty: Bool { points.allSatisfy { $0.value == nil } }

    var maximum: Double {
        let top = points.compactMap(\.value).max() ?? 0
        return top == 0 ? 0.01 : top * 1.15
    }

    var minimum: Double {
        (points.compactMap(\.value).min() ?? 0) * 0.8
    }

    /// The chart in a sentence, for VoiceOver.
    var accessibilityText: String {
        let values = points.compactMap(\.value)
        guard let low = values.min(), let high = values.max() else { return title }
        return String(
            localized: "\(title), from \(AnalyticsText.percent(low)) to \(AnalyticsText.percent(high)); pushed on \(AnalyticsText.day(changeDay.date)).",
            comment: "kind:accessibility-label · After Changes chart"
        )
    }

    /// The chart of `result`'s step in `dataset`; nil for price changes
    /// and without data.
    static func make(_ result: ChangeResult, dataset: AnalyticsDataset, context: AnalyticsContext) -> ChangeChart? {
        guard let stage = result.change.stage else { return nil }
        var filter = FactFilter(source: result.change.kind.source)
        let territories = context.territories(showing: result.change.localeCodes)
        if !territories.isEmpty { filter.territories = territories }
        let days = result.before.days + result.after.days
        let shown = Set(days)
        let zero = FunnelTotals(impressions: 0, pageViews: 0, downloads: 0, trials: 0, paid: 0)
        var byDay: [AnalyticsDay: FunnelTotals] = [:]
        for fact in dataset.engagement where shown.contains(fact.day) && filter.matches(fact) {
            var totals = byDay[fact.day] ?? zero
            totals.impressions = (totals.impressions ?? 0) + fact.impressions
            totals.pageViews = (totals.pageViews ?? 0) + fact.pageViews
            totals.downloads = (totals.downloads ?? 0) + fact.downloads
            byDay[fact.day] = totals
        }
        if filter.allowsSales {
            for event in dataset.events where shown.contains(event.day) && filter.matches(territory: event.territory, device: event.device) {
                var totals = byDay[event.day] ?? zero
                switch event.kind {
                case .trialStart: totals.trials = (totals.trials ?? 0) + event.quantity
                case .paidFromTrial, .paidStart: totals.paid = (totals.paid ?? 0) + event.quantity
                default: continue
                }
                byDay[event.day] = totals
            }
        }
        let points = days.map { FunnelChartPoint(day: $0, value: byDay[$0]?.fraction(stage)) }
        let chart = ChangeChart(stage: stage, points: points, changeDay: result.change.day, afterStart: result.before.length)
        return chart.isEmpty ? nil : chart
    }
}
