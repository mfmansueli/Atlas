//
//  FindingRules.swift
//  Atlas
//

import Foundation

/// Atlas's own findings, worked out from the numbers after each
/// download. Each one names a likely cause it can see, and never more
/// than the data supports.
enum FindingRules {
    /// A price this many times the purchasing-power price is worth saying.
    static let priceRatio = 1.3
    /// This share of cancellations before the first renewal is worth saying.
    static let earlyCancellationShare = 0.4
    /// Territories with a finding each, at most.
    static let territoryLimit = 3

    static func findings(_ dataset: AnalyticsDataset, context: AnalyticsContext, now: Date = .now) -> [AnalyticsFinding] {
        let fromReports = reportFindings(dataset, now: now)
        guard let period = dataset.period(length: 28), dataset.dayCount >= 28 else { return fromReports }
        let totals = dataset.totals(in: period)
        var findings: [AnalyticsFinding] = []
        findings += steps(dataset, now: now)
        findings += territories(dataset, period: period, totals: totals, context: context, now: now)
        findings += trialPrices(dataset, period: period, context: context, now: now)
        if let early = earlyCancellations(dataset, period: period, context: context, now: now) { findings.append(early) }
        return findings + fromReports
    }

    /// A step that fell against the previous 28 days.
    private static func steps(_ dataset: AnalyticsDataset, now: Date) -> [AnalyticsFinding] {
        guard let report = FunnelReport.make(dataset, days: 28), let worst = report.worstStep, let comparison = worst.comparison,
              let before = report.previousTotals?.rate(worst.stage)
        else { return [] }
        let name = worst.stage.rateTitle
        let action: FindingAction = switch worst.stage.fixSection {
        case .screenshots: .screenshots(locale: nil)
        case .storePage: .storePage(locale: nil)
        case .inAppTexts: .inAppTexts
        case .pricing: .pricing(territory: nil)
        case .retention: .retention
        case .productPages: .productPage(name: nil)
        case .stability: .stability
        case .billing: .billing
        }
        return [AnalyticsFinding(
            id: "step.\(worst.stage.rawValue)", source: .builtIn,
            title: String(localized: "\(name) fell from \(before.text) to \(worst.rate.text)."),
            why: stepWhy(worst.stage),
            numbers: [
                FindingNumber(label: String(localized: "Last 28 days"), value: worst.rate.text),
                FindingNumber(label: String(localized: "28 days before"), value: before.text),
                FindingNumber(label: String(localized: "Difference"), value: comparison.pointsText),
            ],
            sureness: comparison.outcome == .lower(.sure) ? String(localized: "Sure") : String(localized: "Fairly sure"),
            surenessDetail: worst.rate.detail(),
            action: action, date: now, signal: worst.rate.fraction
        )]
    }

    private static func stepWhy(_ stage: FunnelStage) -> String {
        switch stage {
        case .impressions, .pageViews:
            String(localized: "In search and browse people see the icon, the name, the subtitle and the first three screenshots. Those carry this step.")
        case .downloads:
            String(localized: "On the page people read the first lines of the description, look at the screenshots and check the ratings.")
        case .trials:
            String(localized: "After downloading, people meet the paywall: its text and the trial it offers carry this step.")
        case .paid:
            String(localized: "At the end of a trial the price decides. Check it against each country’s purchasing power.")
        }
    }

    /// Territories that download (or open the page) surely less than the
    /// app's average, with what their page looks like.
    private static func territories(
        _ dataset: AnalyticsDataset, period: AnalyticsPeriod, totals: FunnelTotals, context: AnalyticsContext, now: Date
    ) -> [AnalyticsFinding] {
        guard let average = totals.fraction(.downloads), dataset.hasEngagement else { return [] }
        let table = BreakdownTable.make(dataset, dimension: .territory, period: period, context: context)
        let name = dataset.appName
        let worse = table.rows.compactMap { row -> (BreakdownRow, MeasuredRate, Double)? in
            guard let rate = row.downloadRate.measured, rate.standing == .worse, rate.bars >= 2, let views = row.totals.pageViews else { return nil }
            // Downloads lost against the average: what fixing it is worth.
            return (row, rate, (average - rate.value) * Double(views))
        }
        return worse.sorted { $0.2 > $1.2 }.prefix(territoryLimit).map { row, rate, _ in
            let locale = context.locale(for: row.id)
            var causes: [String] = []
            switch context.textState(for: row.id) {
            case .machineTranslated: causes.append(String(localized: "The \(locale?.name ?? "") page is machine-translated."))
            case .noPage: causes.append(String(localized: "There’s no page in its language: it shows the \(locale?.name ?? "") one."))
            case .written, nil: break
            }
            var second: FindingAction?
            if context.hasOwnScreenshots(for: row.id) == false {
                causes.append(String(localized: "It uses another language’s screenshots."))
                second = .screenshots(locale: locale?.code)
            }
            let why = causes.isEmpty
                ? String(localized: """
                Its page and screenshots are in its own language, so look at what they say: the first lines and the first three \
                screenshots.
                """)
                : causes.joined(separator: " ")
            return AnalyticsFinding(
                id: "territory.downloads.\(row.id)", source: .builtIn,
                title: String(localized: "\(row.name) downloads less often than \(name)’s average."),
                why: why,
                numbers: [
                    FindingNumber(label: String(localized: "Downloads per page view"), value: row.downloadRate.text, note: String(localized: "\(name) \(AnalyticsText.percent(average))")),
                    FindingNumber(label: String(localized: "Page views per impression"), value: row.viewRate.text),
                    FindingNumber(label: String(localized: "Page views, 28 days"), value: AnalyticsText.count(row.totals.pageViews ?? 0)),
                ],
                sureness: rate.sureness,
                surenessDetail: row.downloadRate.detail(averageName: name, average: average),
                action: .storePage(locale: locale?.code), secondAction: second, date: now, signal: rate.value
            )
        }
    }

    /// Territories whose trials convert surely less than average while the
    /// price is well above purchasing power.
    private static func trialPrices(_ dataset: AnalyticsDataset, period: AnalyticsPeriod, context: AnalyticsContext, now: Date) -> [AnalyticsFinding] {
        guard let report = SubscriptionsReport.make(dataset, period: period), let average = report.trialAverage else { return [] }
        let name = dataset.appName
        return report.territories.compactMap { row -> AnalyticsFinding? in
            guard let price = context.prices[row.code], price.ratio >= priceRatio else { return nil }
            // Trials are few: the range, not the minimum, decides.
            let interval = AnalyticsStatistics.wilson(count: row.paid, total: row.ended)
            guard row.ended >= 20, interval.high < average else { return nil }
            let ratio = price.ratio.formatted(.number.precision(.fractionLength(1)))
            return AnalyticsFinding(
                id: "territory.paid.\(row.code)", source: .builtIn,
                title: String(localized: "\(row.name) converts trials to paid less often than \(name)’s average."),
                why: String(localized: "The \(price.productName) price there is \(ratio)× the purchasing-power price."),
                numbers: [
                    FindingNumber(
                        label: String(localized: "Trial → paid"), value: String(localized: "\(row.paid) of \(row.ended)"),
                        note: String(localized: "\(name) \(AnalyticsText.wholePercent(average))")
                    ),
                    FindingNumber(
                        label: String(localized: "\(price.productName) price"), value: price.priceText,
                        note: String(localized: "purchasing power \(price.suggestedText)")
                    ),
                ],
                sureness: String(localized: "Fairly sure"),
                surenessDetail: String(
                    localized: "\(row.paid) of \(row.ended) trials became paid. Few trials, but the 90% range \(AnalyticsText.wholePercent(interval.low))–\(AnalyticsText.wholePercent(interval.high)) stays below \(name)’s \(AnalyticsText.wholePercent(average))."
                ),
                action: .pricing(territory: row.code), date: now, signal: interval.value
            )
        }
    }

    /// Many cancellations before the first renewal, and nothing shown to
    /// people when they tap Cancel Subscription.
    private static func earlyCancellations(
        _ dataset: AnalyticsDataset, period: AnalyticsPeriod, context: AnalyticsContext, now: Date
    ) -> AnalyticsFinding? {
        guard context.liveRetentionMessages == 0, let report = SubscriptionsReport.make(dataset, period: period),
              let share = report.earlyShare.measured, share.low >= earlyCancellationShare
        else { return nil }
        return AnalyticsFinding(
            id: "retention.early", source: .builtIn,
            title: String(localized: "\(AnalyticsText.wholePercent(share.value)) of cancellations come before the first renewal, and no retention message is live."),
            why: String(
                localized: """
                People decide right before they’re charged the full price for the first time. A message and an offer reach them \
                when they tap Cancel Subscription.
                """
            ),
            numbers: [
                FindingNumber(label: String(localized: "Cancellations, 28 days"), value: AnalyticsText.count(report.cancellations)),
                FindingNumber(
                    label: String(localized: "Before the first renewal"), value: AnalyticsText.count(report.earlyCancellations),
                    note: AnalyticsText.wholePercent(share.value)
                ),
                FindingNumber(label: String(localized: "Retention messages live"), value: "0"),
            ],
            sureness: share.sureness,
            surenessDetail: String(
                localized: "\(report.earlyCancellations) of \(report.cancellations) cancellations, 90% range \(AnalyticsText.wholePercent(share.low))–\(AnalyticsText.wholePercent(share.high))."
            ),
            action: .retention, date: now, signal: share.value
        )
    }
}
