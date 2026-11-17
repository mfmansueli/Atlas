//
//  ChangeResult+Make.swift
//  Atlas
//

import Foundation

extension ChangeResult {
    /// Measures `change` in `dataset`; nil for price changes (Pricing →
    /// Results has them) and without data.
    static func make(_ change: MeasuredChange, dataset: AnalyticsDataset, context: AnalyticsContext) -> ChangeResult? {
        guard let stage = change.stage, let through = dataset.through, let first = dataset.firstDay else { return nil }
        let window = ResultsEvaluator.windowDays
        let before = AnalyticsPeriod(ending: change.day.adding(-1), length: window)
        let fullAfter = AnalyticsPeriod(first: change.day, last: change.day.adding(window - 1))
        let after = AnalyticsPeriod(first: change.day, last: min(fullAfter.last, max(through, change.day)))
        let state: State = if before.last < first {
            .noBefore
        } else if through < fullAfter.last {
            .measuring(day: max(after.length, 1), ends: fullAfter.last.date)
        } else {
            .final
        }
        var filter = FactFilter(source: change.kind.source)
        let territories = context.territories(showing: change.localeCodes)
        if !territories.isEmpty { filter.territories = territories }
        let totalsBefore = dataset.totals(in: before, filter: filter)
        let totalsAfter = dataset.totals(in: after, filter: filter)
        // Sales aren't split by source: the other steps use the territories only.
        var open = filter
        open.source = nil
        let openBefore = dataset.totals(in: before, filter: open)
        let openAfter = dataset.totals(in: after, filter: open)
        func side(_ stage: FunnelStage, title: String, _ lhs: FunnelTotals, _ rhs: FunnelTotals) -> Side? {
            guard let previous = stage.previous, FunnelReport.gap(for: stage, in: dataset) == nil else { return nil }
            return Side(
                title: title, before: lhs.rate(stage), after: rhs.rate(stage),
                comparison: AnalyticsStatistics.compare(
                    count: rhs.count(stage), total: rhs.count(previous), previousCount: lhs.count(stage), previousTotal: lhs.count(previous)
                )
            )
        }
        guard let main = side(stage, title: change.stageTitle, totalsBefore, totalsAfter) else { return nil }
        let others = change.kind.otherStages.compactMap { side($0, title: $0.rateTitle, openBefore, openAfter) }
        return ChangeResult(change: change, state: state, before: before, after: after, main: main, others: others)
    }
}
