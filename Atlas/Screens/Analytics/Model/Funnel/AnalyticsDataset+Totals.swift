//
//  AnalyticsDataset+Totals.swift
//  Atlas
//

import Foundation

extension AnalyticsDataset {
    /// The funnel's counts in `period` for the facts `filter` lets through.
    func totals(in period: AnalyticsPeriod, filter: FactFilter = .all) -> FunnelTotals {
        var totals = FunnelTotals()
        if engagementState == .ready {
            var impressions = 0, pageViews = 0, downloads = 0
            for fact in engagement where period.contains(fact.day) && filter.matches(fact) {
                impressions += fact.impressions
                pageViews += fact.pageViews
                downloads += fact.downloads
            }
            totals.impressions = impressions
            totals.pageViews = pageViews
            totals.downloads = downloads
        }
        guard hasSales, filter.allowsSales else { return totals }
        var trials = 0, paid = 0, direct = 0
        for event in events where period.contains(event.day) && filter.matches(territory: event.territory, device: event.device) {
            switch event.kind {
            case .trialStart: trials += event.quantity
            case .paidFromTrial: paid += event.quantity
            case .paidStart:
                paid += event.quantity
                direct += event.quantity
            default: break
            }
        }
        totals.trials = trials
        totals.paid = paid
        totals.starts = trials + direct
        totals.proceeds = subscribers
            .filter { period.contains($0.day) && filter.matches(territory: $0.territory, device: $0.device) }
            .reduce(Decimal(0)) { $0 + $1.proceeds }
        return totals
    }

    /// The last `length` days of data, or nil without any.
    func period(length: Int) -> AnalyticsPeriod? {
        through.map { AnalyticsPeriod(ending: $0, length: length) }
    }

    /// Everything kept, for the app's long-run average.
    var wholePeriod: AnalyticsPeriod? {
        guard let first = firstDay, let last = through else { return nil }
        return AnalyticsPeriod(first: first, last: last)
    }
}
