//
//  FunnelChart+Make.swift
//  Atlas
//

import Foundation

extension FunnelChart {
    /// The chart of `stage` under `report`.
    static func make(_ dataset: AnalyticsDataset, report: FunnelReport, stage: FunnelStage, changes: [MeasuredChange]) -> FunnelChart {
        let gap = FunnelReport.gap(for: stage, in: dataset) ?? stage.previous.flatMap { FunnelReport.gap(for: $0, in: dataset) }
        let days = (report.previous?.days ?? []) + report.period.days
        var chart = FunnelChart(stage: stage, points: [], currentStart: report.previous?.length ?? 0, average: nil, marks: [], gap: gap)
        guard gap == nil else { return chart }
        let byDay = dailyCounts(dataset)
        chart.points = days.map { day in
            let counts = byDay[day] ?? FunnelTotals(impressions: 0, pageViews: 0, downloads: 0, trials: 0, paid: 0)
            if stage == .impressions { return FunnelChartPoint(day: day, value: Double(counts.impressions ?? 0)) }
            return FunnelChartPoint(day: day, value: counts.fraction(stage))
        }
        if stage != .impressions, !report.isNew, let whole = dataset.wholePeriod, whole.length > report.days * 2 {
            chart.average = dataset.totals(in: whole).fraction(stage)
        }
        let shown = Set(days)
        chart.marks = changes.filter { shown.contains($0.day) }
        return chart
    }

    /// Every day's counts, in one pass.
    private static func dailyCounts(_ dataset: AnalyticsDataset) -> [AnalyticsDay: FunnelTotals] {
        var byDay: [AnalyticsDay: FunnelTotals] = [:]
        let zero = FunnelTotals(impressions: 0, pageViews: 0, downloads: 0, trials: 0, paid: 0)
        for fact in dataset.engagement {
            var totals = byDay[fact.day] ?? zero
            totals.impressions = (totals.impressions ?? 0) + fact.impressions
            totals.pageViews = (totals.pageViews ?? 0) + fact.pageViews
            totals.downloads = (totals.downloads ?? 0) + fact.downloads
            byDay[fact.day] = totals
        }
        for event in dataset.events {
            var totals = byDay[event.day] ?? zero
            switch event.kind {
            case .trialStart: totals.trials = (totals.trials ?? 0) + event.quantity
            case .paidFromTrial, .paidStart: totals.paid = (totals.paid ?? 0) + event.quantity
            default: continue
            }
            byDay[event.day] = totals
        }
        return byDay
    }
}
