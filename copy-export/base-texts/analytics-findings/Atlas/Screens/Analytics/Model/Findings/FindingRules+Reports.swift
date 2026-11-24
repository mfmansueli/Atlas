//
//  FindingRules+Reports.swift
//  Atlas
//

import Foundation

/// Findings from Apple's newer reports: the cancel screen, billing, pages
/// people delete, crashes and offers. Each says something only when the
/// two sides are clearly apart (at least fairly sure).
extension FindingRules {
    /// Lost to billing a month that makes Billing Grace Period worth saying.
    static let lostToBillingPerMonth = 10

    static func reportFindings(_ dataset: AnalyticsDataset, now: Date) -> [AnalyticsFinding] {
        let reports = dataset.reports
        guard !reports.isEmpty else { return [] }
        var findings: [AnalyticsFinding] = []
        if let retention = RetentionReport.make(reports, days: 28) {
            findings += retentionFindings(retention, now: now)
        }
        let last = AppleReportKind.allCases.compactMap { reports.lastDay($0) }.max()
        if let last {
            let period = AnalyticsPeriod(ending: last, length: 28)
            if let lifecycle = LifecycleReport.make(reports, period: period) {
                if let billing = billingFinding(lifecycle, gracePeriod: dataset.gracePeriod, now: now) { findings.append(billing) }
                findings += offerFindings(lifecycle, now: now)
            }
            findings += pageFindings(reports, period: period, now: now)
        }
        if let stability = StabilityReport.make(reports, now: AnalyticsDay(now)) {
            if let crash = crashFinding(stability, now: now) {
                findings.append(crash)
            } else if let deletions = deletionFinding(reports, stability: stability, now: now) {
                findings.append(deletions)
            }
        }
        return findings
    }

    // MARK: - Retention

    private static func retentionFindings(_ report: RetentionReport, now: Date) -> [AnalyticsFinding] {
        var findings: [AnalyticsFinding] = []
        let offers = report.messages.filter { !$0.isNoMessage && $0.type.lowercased().contains("offer") }
        let texts = report.messages.filter { !$0.isNoMessage && !$0.type.lowercased().contains("offer") }
        let offerCounts = (opened: offers.reduce(0) { $0 + $1.opened }, stayed: offers.reduce(0) { $0 + $1.stayed })
        let textCounts = (opened: texts.reduce(0) { $0 + $1.opened }, stayed: texts.reduce(0) { $0 + $1.stayed })
        if !offers.isEmpty, !texts.isEmpty, case let .higher(confidence) = RetentionReport.groupComparison(offerCounts, against: textCounts) {
            let offerRate = AnalyticsStatistics.rate(count: offerCounts.stayed, total: offerCounts.opened)
            let textRate = AnalyticsStatistics.rate(count: textCounts.stayed, total: textCounts.opened)
            findings.append(AnalyticsFinding(
                id: "retention.offerMessage", source: .builtIn,
                title: String(localized: "Messages with an offer keep \(offerRate.text) of people at the cancel screen; text alone keeps \(textRate.text)."),
                why: String(localized: """
                An offer gives people a reason to stay that words alone don’t. \
                Try an offer in the text-only messages, starting with the subscription most people cancel.
                """),
                numbers: [
                    FindingNumber(label: String(localized: "With an offer"), value: offerRate.text),
                    FindingNumber(label: String(localized: "Text only"), value: textRate.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(offerCounts.stayed)) of \(AnalyticsText.count(offerCounts.opened)) against \(AnalyticsText.count(textCounts.stayed)) of \(AnalyticsText.count(textCounts.opened)), last 28 complete days"),
                action: .retention, date: now, signal: offerRate.fraction
            ))
        }
        if report.noMessageOpened > 0, case let .higher(confidence) = report.withAgainstWithout {
            findings.append(AnalyticsFinding(
                id: "retention.noMessage", source: .builtIn,
                title: String(localized: "People who see Apple’s plain cancel screen stay less: \(report.noMessage.text) against \(report.withMessage.text) with a message."),
                why: String(localized: "\(AnalyticsText.count(report.noMessageOpened)) people reached the cancel screen where no message applies: a subscription or a country your messages don’t cover. A message there could keep some of them."),
                numbers: [
                    FindingNumber(label: String(localized: "No Message"), value: report.noMessage.text),
                    FindingNumber(label: String(localized: "With a message"), value: report.withMessage.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(report.noMessageStayed)) of \(AnalyticsText.count(report.noMessageOpened)) against \(AnalyticsText.count(report.withMessageStayed)) of \(AnalyticsText.count(report.withMessageOpened))"),
                action: .retention, date: now, signal: report.noMessage.fraction
            ))
        }
        return findings
    }

    // MARK: - Billing

    /// Only when App Store Connect says Billing Grace Period is off.
    private static func billingFinding(_ report: LifecycleReport, gracePeriod: GracePeriodSetting?, now: Date) -> AnalyticsFinding? {
        guard let gracePeriod, !gracePeriod.isOn, report.lostPerMonth >= lostToBillingPerMonth else { return nil }
        return AnalyticsFinding(
            id: "billing.gracePeriod", source: .builtIn,
            title: String(localized: "\(AnalyticsText.count(report.lost)) subscribers left in 28 days because Apple couldn’t charge them."),
            why: String(localized: """
            Billing Grace Period is off. With it on, people keep their subscription for 3, 16 or 28 days while Apple retries the charge, \
            and more of them pay before they’d lose access.
            """),
            numbers: [
                FindingNumber(label: String(localized: "Couldn’t be charged"), value: AnalyticsText.count(report.couldNotCharge)),
                FindingNumber(label: String(localized: "Recovered"), value: AnalyticsText.count(report.recovered)),
                FindingNumber(label: String(localized: "Lost"), value: AnalyticsText.count(report.lost)),
            ],
            sureness: String(localized: "Sure"),
            surenessDetail: String(localized: "Counted by Apple’s subscription event report, every subscriber"),
            action: .billing, date: now, signal: Double(report.lost)
        )
    }

    // MARK: - Offers

    private static func offerFindings(_ report: LifecycleReport, now: Date) -> [AnalyticsFinding] {
        guard let average = report.offerAverage else { return [] }
        return report.offers.compactMap { offer -> AnalyticsFinding? in
            guard offer.standing == .worse, let measured = offer.rate.measured else { return nil }
            return AnalyticsFinding(
                id: "offer.\(offer.name)", source: .builtIn,
                title: String(localized: "\(offer.name) brought \(AnalyticsText.count(offer.started)) people and \(AnalyticsText.count(offer.paidAfterwards)) stayed at full price."),
                why: String(localized: "That’s \(AnalyticsText.percent(measured.value)) against \(AnalyticsText.percent(average)) for your offers together. Check who it reaches and whether its length or price lets people leave before they see the app’s value."),
                numbers: [
                    FindingNumber(label: String(localized: "Paid afterwards"), value: AnalyticsText.percent(measured.value)),
                    FindingNumber(label: String(localized: "Every offer"), value: AnalyticsText.percent(average)),
                ],
                sureness: measured.sureness,
                surenessDetail: offer.rate.detail(),
                action: .pricing(territory: nil), date: now, signal: measured.value
            )
        }
    }

    // MARK: - Product pages

    /// A custom page whose downloads are deleted within 30 days clearly
    /// more often than the default page's.
    private static func pageFindings(_ reports: ReportsArchive, period: AnalyticsPeriod, now: Date) -> [AnalyticsFinding] {
        let defaultName = ProductPageNumbers.defaultPageName
        let byPage = Dictionary(grouping: reports.records(.installs).within(period)) { ReportsArchive.pageName($0, defaultName: defaultName) ?? "" }
        guard byPage[defaultName] != nil else { return [] }
        let reference = AfterDownloadNumbers.make(reports, period: period) { ReportsArchive.pageName($0, defaultName: defaultName) == defaultName }
        return byPage.keys.filter { !$0.isEmpty && $0 != defaultName }.sorted().compactMap { page -> AnalyticsFinding? in
            let numbers = AfterDownloadNumbers.make(reports, period: period) { ReportsArchive.pageName($0, defaultName: defaultName) == page }
            let outcome = AnalyticsStatistics.compare(
                count: min(numbers.recentDeletions, numbers.installs), total: numbers.installs,
                previousCount: min(reference.recentDeletions, reference.installs), previousTotal: reference.installs,
                minimumTotal: AnalyticsStatistics.minimumTotal, minimumCount: AnalyticsStatistics.minimumCount
            ).outcome
            guard case let .higher(confidence) = outcome else { return nil }
            let rate = numbers.deletedWithin30
            let base = reference.deletedWithin30
            return AnalyticsFinding(
                id: "page.deletes.\(page)", source: .builtIn,
                title: String(localized: "People who came through “\(page)” delete the app more: \(rate.text) within 30 days, against \(base.text) from the default page."),
                why: String(localized: """
                The page may promise something the app’s first minutes don’t show. \
                Compare its screenshots and text with what people see when they open the app.
                """),
                numbers: [
                    FindingNumber(label: String(localized: "Deleted in 30 days"), value: rate.text),
                    FindingNumber(label: String(localized: "Default page"), value: base.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(numbers.recentDeletions)) of \(AnalyticsText.count(numbers.installs)) installs, a sample of people who share analytics"),
                action: .productPage(name: page), date: now, signal: rate.fraction
            )
        }
    }

    // MARK: - Versions

    private static func crashFinding(_ report: StabilityReport, now: Date) -> AnalyticsFinding? {
        guard let headline = report.headline, case let .higher(confidence) = report.comparison, let previous = report.previous else { return nil }
        let new = report.latest.perThousand.map(AnalyticsText.perThousand) ?? "—"
        let old = previous.perThousand.map(AnalyticsText.perThousand) ?? "—"
        return AnalyticsFinding(
            id: "stability.crashes.\(report.latest.version)", source: .builtIn,
            title: headline,
            why: report.mostAffected.map { String(localized: "Most of the difference is on \($0.device). If the version is rolling out in phases, pausing keeps it from reaching more people while you fix it.") }
                ?? String(localized: "If the version is rolling out in phases, pausing keeps it from reaching more people while you fix it."),
            numbers: [
                FindingNumber(label: String(localized: "Crashes per 1,000 sessions · \(report.latest.version)"), value: new),
                FindingNumber(label: previous.version, value: old),
            ],
            sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
            surenessDetail: String(localized: "\(AnalyticsText.count(report.latest.crashes)) crashes in \(AnalyticsText.count(report.latest.sessions)) sessions against \(AnalyticsText.count(previous.crashes)) in \(AnalyticsText.count(previous.sessions)), a sample"),
            action: .stability, date: now, signal: report.times
        )
    }

    /// Deletions rose with the newest version while crashes didn't: what
    /// changed is likely in the app itself.
    private static func deletionFinding(_ reports: ReportsArchive, stability: StabilityReport, now: Date) -> AnalyticsFinding? {
        guard let previous = stability.previous, stability.comparison == .same || stability.comparison.isLower else { return nil }
        let new = AfterDownloadNumbers.make(reports, period: stability.period) { $0[.appVersion] == stability.latest.version }
        let old = AfterDownloadNumbers.make(reports, period: stability.period) { $0[.appVersion] == previous.version }
        guard new.deviceDays > 0, old.deviceDays > 0 else { return nil }
        let outcome = AnalyticsStatistics.compare(
            count: min(new.deletions, new.deviceDays), total: new.deviceDays, previousCount: min(old.deletions, old.deviceDays), previousTotal: old.deviceDays,
            minimumTotal: AnalyticsStatistics.minimumTotal, minimumCount: AnalyticsStatistics.minimumCount
        ).outcome
        guard case let .higher(confidence) = outcome else { return nil }
        let newRate = Double(new.deletions) * 1000 / Double(new.deviceDays)
        let oldRate = Double(old.deletions) * 1000 / Double(old.deviceDays)
        return AnalyticsFinding(
            id: "stability.deletions.\(stability.latest.version)", source: .builtIn,
            title: String(localized: "People delete version \(stability.latest.version) more often than \(previous.version), and it doesn’t crash more."),
            why: String(localized: """
            Something in what changed may put people off: a new screen, a paywall moved earlier, a feature removed. \
            Look at the version’s reviews and what’s new.
            """),
            numbers: [
                FindingNumber(label: String(localized: "Deletions per 1,000 active devices · \(stability.latest.version)"), value: AnalyticsText.perThousand(newRate)),
                FindingNumber(label: previous.version, value: AnalyticsText.perThousand(oldRate)),
            ],
            sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
            surenessDetail: String(localized: "Same days, a sample of people who share analytics"),
            action: .stability, date: now, signal: newRate
        )
    }
}
