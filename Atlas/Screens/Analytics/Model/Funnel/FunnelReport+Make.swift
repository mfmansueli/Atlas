//
//  FunnelReport+Make.swift
//  Atlas
//

import Foundation

extension FunnelReport {
    /// The funnel of `dataset`'s last `days` days; nil without any data.
    static func make(_ dataset: AnalyticsDataset, days: Int, changes: [MeasuredChange] = []) -> FunnelReport? {
        guard let through = dataset.through, let first = dataset.firstDay else { return nil }
        let isNew = dataset.dayCount < days
        let period = isNew ? AnalyticsPeriod(first: first, last: through) : AnalyticsPeriod(ending: through, length: days)
        let previous: AnalyticsPeriod? = !isNew && period.previous.first >= first ? period.previous : nil
        let totals = dataset.totals(in: period)
        let previousTotals = previous.map { dataset.totals(in: $0) }
        let stages = dataset.sellsSubscriptions ? FunnelStage.allCases : FunnelStage.storePage
        let steps = stages.map { stage in
            step(stage, dataset: dataset, totals: totals, previousTotals: previousTotals)
        }
        var report = FunnelReport(
            days: days, period: period, previous: previous, isNew: isNew, steps: steps, totals: totals, previousTotals: previousTotals,
            callout: FunnelCallout(kind: .steady, title: "", text: "")
        )
        report.callout = callout(for: report, dataset: dataset, changes: changes)
        (report.note, report.noteIsWarning) = note(for: dataset)
        return report
    }

    static func gap(for stage: FunnelStage, in dataset: AnalyticsDataset) -> FunnelGap? {
        if stage.isSales {
            switch dataset.salesState {
            case .ready: return nil
            case .needsVendorNumber: return .needsVendorNumber
            case .keyCannotRead: return .keyCannotReadSales
            case .waiting: return .salesWaiting
            }
        }
        if case let .waiting(asked) = dataset.engagementState { return .engagementWaiting(asked: asked) }
        return nil
    }

    private static func step(_ stage: FunnelStage, dataset: AnalyticsDataset, totals: FunnelTotals, previousTotals: FunnelTotals?) -> FunnelStep {
        let gap = gap(for: stage, in: dataset)
        let previousGap = stage.previous.flatMap { self.gap(for: $0, in: dataset) }
        let count = gap == nil ? totals.count(stage) : nil
        var step = FunnelStep(stage: stage, count: count, gap: gap, rate: .missing)
        step.change = gap == nil ? AnalyticsText.change(count, from: previousTotals?.count(stage)) : nil
        guard let before = stage.previous, gap == nil, previousGap == nil else { return step }
        step.rate = totals.rate(stage)
        if let previousTotals {
            step.comparison = AnalyticsStatistics.compare(
                count: totals.count(stage), total: totals.count(before),
                previousCount: previousTotals.count(stage), previousTotal: previousTotals.count(before)
            )
        }
        return step
    }

    private static func callout(for report: FunnelReport, dataset: AnalyticsDataset, changes: [MeasuredChange]) -> FunnelCallout {
        let name = dataset.appName
        let views = report.totals.pageViews ?? 0
        let downloads = report.totals.downloads ?? 0
        if report.isNew {
            return FunnelCallout(
                kind: .newApp,
                title: String(localized: "\(name) has \(dataset.dayCount) days of data"),
                text: String(localized: "Comparisons start after a full period. Until then the funnel shows counts and rates, without “better” or “worse”.")
            )
        }
        if dataset.hasEngagement, views < AnalyticsStatistics.minimumTotal || downloads < AnalyticsStatistics.minimumCount {
            return FunnelCallout(
                kind: .tooFew,
                title: String(localized: "Too few to tell"),
                text: String(
                    localized: "\(name) had \(AnalyticsText.count(views)) page views and \(AnalyticsText.count(downloads)) downloads in \(report.days) days. Rates this small move by chance, so they’re shown as counts. Switch to 90 days, or look at what people see first: the screenshots and subtitle."
                )
            )
        }
        if let worst = report.worstStep, let comparison = worst.comparison {
            let before = report.previousTotals?.fraction(worst.stage).map(AnalyticsText.percent) ?? "—"
            var actions: [FunnelCalloutAction] = []
            // The change pushed inside the period, nearest its start: the
            // likeliest cause of a drop.
            if let change = changes.filter({ report.period.contains($0.day) && $0.stage == worst.stage }).min(by: { $0.day < $1.day }) {
                actions.append(.seeChange(change.id))
            }
            if !worst.stage.isSales { actions.append(.breakDown(worst.stage == .pageViews ? .source : .territory)) }
            return FunnelCallout(
                kind: .loss(worst.stage),
                title: String(localized: "Biggest loss: \(worst.stage.rateTitle.localizedLowercase)"),
                text: String(localized: "\(worst.rate.text), down from \(before) in the previous \(report.days) days (\(comparison.outcome.title))."),
                actions: actions
            )
        }
        if !dataset.sellsSubscriptions {
            let rate = report.totals.rate(.downloads).text
            return FunnelCallout(
                kind: .noSubscription,
                title: String(localized: "\(name) has no subscription, so the funnel ends at downloads"),
                text: String(localized: "\(AnalyticsText.count(downloads)) first-time downloads. Downloads per page view: \(rate).")
            )
        }
        guard report.previous != nil else {
            return FunnelCallout(
                kind: .steady,
                title: String(localized: "No earlier period to compare yet"),
                text: String(localized: "\(name) has \(dataset.dayCount) days of data; comparing \(report.days) days needs \(report.days * 2).")
            )
        }
        return FunnelCallout(
            kind: .steady,
            title: String(localized: "No step is worse than before"),
            text: String(localized: "Every step is about the same as the previous \(report.days) days, or better.")
        )
    }

    private static func note(for dataset: AnalyticsDataset) -> (String?, Bool) {
        guard dataset.sellsSubscriptions else { return (nil, false) }
        switch dataset.salesState {
        case .needsVendorNumber:
            return (String(localized: "Store-page numbers work without a vendor number. Trials, paid starts and proceeds need it."), true)
        case .keyCannotRead:
            return (String(localized: "Your key’s role can’t read sales. Keys with the Admin, Finance or Sales role can."), true)
        case .waiting:
            return (String(localized: "Impressions, page views and downloads have arrived. Sales come in a separate report from Apple."), false)
        case .ready:
            if case .waiting = dataset.engagementState {
                return (String(localized: "Sales arrived. Impressions, page views and downloads come in Apple’s analytics reports."), false)
            }
            let text = String(
                localized: """
                Paid starts include trials that converted and people who subscribed without a trial. Trials that started in the \
                last 7 days can’t have converted yet.
                """
            )
            return (text, false)
        }
    }
}
