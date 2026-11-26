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

    /// `context` names the languages No Message's territories see, for
    /// Write Messages for N Languages….
    static func reportFindings(_ dataset: AnalyticsDataset, context: AnalyticsContext = .empty, now: Date) -> [AnalyticsFinding] {
        let reports = dataset.reports
        guard !reports.isEmpty else { return [] }
        var findings: [AnalyticsFinding] = []
        if let retention = RetentionReport.make(reports, days: 28) {
            findings += retentionFindings(retention, context: context, now: now)
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

    private static func retentionFindings(_ report: RetentionReport, context: AnalyticsContext, now: Date) -> [AnalyticsFinding] {
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
                title: String(localized: "Offer messages keep \(offerRate.text); text alone, \(textRate.text)"),
                why: String(localized: """
                Offers give a reason to stay. Add one to text-only messages, starting with the most-canceled \
                subscription.
                """),
                numbers: [
                    FindingNumber(label: String(localized: "With an offer"), value: offerRate.text),
                    FindingNumber(label: String(localized: "Text only"), value: textRate.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(offerCounts.stayed)) of \(AnalyticsText.count(offerCounts.opened)) against \(AnalyticsText.count(textCounts.stayed)) of \(AnalyticsText.count(textCounts.opened)), last 28 complete days"),
                action: .retention, secondAction: .offerMessage, date: now, signal: offerRate.fraction
            ))
        }
        if report.noMessageOpened > 0, case let .higher(confidence) = report.withAgainstWithout {
            let languages = languagesWithoutAMessage(report, context: context)
            findings.append(AnalyticsFinding(
                id: "retention.noMessage", source: .builtIn,
                title: noMessageTitle(report),
                why: String(localized: """
                \(report.noMessage.text) stay without a message, \(report.withMessage.text) with one. \(AnalyticsText.count(report.noMessageOpened)) people hit a cancel \
                screen your messages don’t cover.
                """),
                numbers: [
                    FindingNumber(label: String(localized: "No Message"), value: report.noMessage.text),
                    FindingNumber(label: String(localized: "With a message"), value: report.withMessage.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(report.noMessageStayed)) of \(AnalyticsText.count(report.noMessageOpened)) against \(AnalyticsText.count(report.withMessageStayed)) of \(AnalyticsText.count(report.withMessageOpened))"),
                action: languages > 0 ? .retentionLanguages(count: languages) : .retention, date: now, signal: report.noMessage.fraction
            ))
        }
        return findings
    }

    /// The App Store languages No Message's territories see: where a
    /// message would reach people who get Apple's plain screen now. 0 when
    /// the page's languages aren't known.
    static func languagesWithoutAMessage(_ report: RetentionReport, context: AnalyticsContext) -> Int {
        guard !context.pageLocales.isEmpty, let none = report.messages.first(where: \.isNoMessage) else { return 0 }
        return Set(none.territories.compactMap { context.locale(for: $0)?.code }).count
    }

    // MARK: - Billing

    /// Only when App Store Connect says Billing Grace Period is off.
    private static func billingFinding(_ report: LifecycleReport, gracePeriod: GracePeriodSetting?, now: Date) -> AnalyticsFinding? {
        guard let gracePeriod, !gracePeriod.isOn, report.lostPerMonth >= lostToBillingPerMonth else { return nil }
        return AnalyticsFinding(
            id: "billing.gracePeriod", source: .builtIn,
            title: String(localized: "\(AnalyticsText.count(report.lost)) lost to failed charges in 28 days"),
            why: String(localized: """
            Billing Grace Period is off. With it, people keep access 3, 16 or 28 days while Apple retries; more pay.
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
                title: String(localized: "\(offer.name): \(AnalyticsText.count(offer.paidAfterwards)) of \(AnalyticsText.count(offer.started)) stayed at full price"),
                why: String(localized: "That’s \(AnalyticsText.percent(measured.value)) against \(AnalyticsText.percent(average)) for all your offers. Check its audience, length and price."),
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
                title: pageDeletesTitle(page: page, rate: rate, base: base),
                why: String(localized: """
                \(rate.text) delete it within 30 days, \(base.text) from the default page. The page may promise what the app \
                doesn’t show.
                """),
                numbers: [
                    FindingNumber(label: String(localized: "Deleted in 30 days"), value: rate.text),
                    FindingNumber(label: String(localized: "Default page"), value: base.text),
                ],
                sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
                surenessDetail: String(localized: "\(AnalyticsText.count(numbers.recentDeletions)) of \(AnalyticsText.count(numbers.installs)) installs, a sample of people who share analytics"),
                action: .productPage(name: page), secondAction: .pageScreenshots(name: page), date: now, signal: rate.fraction
            )
        }
    }

    // MARK: - Versions

    private static func crashFinding(_ report: StabilityReport, now: Date) -> AnalyticsFinding? {
        guard report.headline != nil, let times = report.times, case let .higher(confidence) = report.comparison, let previous = report.previous
        else { return nil }
        let new = report.latest.perThousand.map(AnalyticsText.perThousand) ?? "—"
        let old = previous.perThousand.map(AnalyticsText.perThousand) ?? "—"
        return AnalyticsFinding(
            id: "stability.crashes.\(report.latest.version)", source: .builtIn,
            // At most 8 words: the banner's headline says "on the same days".
            title: String(
                localized: "\(report.latest.version) crashes \(AnalyticsText.times(times)) as often as \(previous.version)", comment: "kind:suggestion-title"
            ),
            why: report.mostAffected.map { String(localized: "Most of it is on \($0.device). In a phased release, pausing stops it reaching more people.") }
                ?? String(localized: "In a phased release, pause it while you fix it."),
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
            title: String(localized: "Deletions rose with \(stability.latest.version); crashes didn’t"),
            why: String(localized: """
            \(AnalyticsText.perThousand(newRate)) per 1,000 devices on \(stability.latest.version), \(AnalyticsText.perThousand(oldRate)) on \
            \(previous.version). Something new may put people off; check its reviews.
            """),
            numbers: [
                FindingNumber(label: String(localized: "Deletions per 1,000 active devices · \(stability.latest.version)"), value: AnalyticsText.perThousand(newRate)),
                FindingNumber(label: previous.version, value: AnalyticsText.perThousand(oldRate)),
            ],
            sureness: confidence == .sure ? String(localized: "Sure") : String(localized: "Fairly sure"),
            surenessDetail: String(localized: "Same days, a sample of people who share analytics"),
            action: .changes, date: now, signal: newRate
        )
    }

    // MARK: - Titles

    /// “No message keeps half as many people” (README-An2, November 25):
    /// the result first; the rates are in the sentence under it.
    private static func noMessageTitle(_ report: RetentionReport) -> String {
        switch times(report.withMessage.fraction, over: report.noMessage.fraction) {
        case 2: String(localized: "No message keeps half as many people", comment: "kind:suggestion-title")
        case 3: String(localized: "No message keeps a third as many people", comment: "kind:suggestion-title")
        case 4: String(localized: "No message keeps a quarter as many people", comment: "kind:suggestion-title")
        default: String(localized: "No message keeps fewer people", comment: "kind:suggestion-title")
        }
    }

    /// “People from “Mood tracking” delete twice as often”: no app name,
    /// which can be several words, so the title stays within 8.
    private static func pageDeletesTitle(page: String, rate: AnalyticsRate, base: AnalyticsRate) -> String {
        switch times(rate.fraction, over: base.fraction) {
        case 2: String(localized: "People from “\(page)” delete twice as often", comment: "kind:suggestion-title")
        case 3: String(localized: "People from “\(page)” delete 3× as often", comment: "kind:suggestion-title")
        case 4: String(localized: "People from “\(page)” delete 4× as often", comment: "kind:suggestion-title")
        default: String(localized: "People from “\(page)” delete more often", comment: "kind:suggestion-title")
        }
    }

    /// 2, 3 or 4 when `value` is about that many times `reference`, for a
    /// title in words; nil otherwise.
    static func times(_ value: Double?, over reference: Double?) -> Int? {
        guard let value, let reference, reference > 0 else { return nil }
        let ratio = value / reference
        let whole = Int(ratio.rounded())
        return (2...4).contains(whole) && abs(ratio - Double(whole)) < 0.35 ? whole : nil
    }
}
