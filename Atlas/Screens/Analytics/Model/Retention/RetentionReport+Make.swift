//
//  RetentionReport+Make.swift
//  Atlas
//

import Foundation

extension RetentionReport {
    /// Weeks the chart shows, at most.
    static let chartWeeks = 8

    /// The last `days` complete days; nil when Apple hasn't sent a row.
    static func make(_ reports: ReportsArchive, days: Int) -> RetentionReport? {
        let records = reports.records(.retention)
        guard let lastDay = records.last?.day else { return nil }
        let through = lastDay.adding(-AppleReportKind.retention.completeAfterDays)
        let period = AnalyticsPeriod(ending: through, length: days)
        let inPeriod = records.within(period)
        let before = records.within(period.previous)
        let totals = counts(inPeriod)
        let previous = counts(before)
        let withMessage = counts(inPeriod.filter { !isNoMessage($0) })
        let noMessage = counts(inPeriod.filter(isNoMessage))
        let messages = Self.messages(inPeriod, noMessage: noMessage)
        return RetentionReport(
            period: period,
            lastDay: lastDay,
            opened: totals.opened,
            stayed: totals.stayed,
            rate: AnalyticsStatistics.rate(count: totals.stayed, total: totals.opened),
            comparison: previous.opened > 0
                ? AnalyticsStatistics.compare(
                    count: totals.stayed, total: totals.opened, previousCount: previous.stayed, previousTotal: previous.opened,
                    minimumTotal: AnalyticsStatistics.minimumTotal, minimumCount: AnalyticsStatistics.minimumCount
                )
                : nil,
            withMessage: AnalyticsStatistics.rate(count: withMessage.stayed, total: withMessage.opened),
            withMessageStayed: withMessage.stayed,
            withMessageOpened: withMessage.opened,
            noMessage: AnalyticsStatistics.rate(count: noMessage.stayed, total: noMessage.opened),
            noMessageStayed: noMessage.stayed,
            noMessageOpened: noMessage.opened,
            withAgainstWithout: groupComparison(withMessage, against: noMessage),
            messages: messages,
            subscriptions: subscriptions(inPeriod),
            saveTypes: saveTypes(inPeriod),
            weeks: weeks(records, through: through)
        )
    }

    /// Opened the cancel screen, and stayed: everyone who didn't cancel.
    static func counts(_ records: [ReportRecord]) -> (opened: Int, stayed: Int) {
        var opened = 0, canceled = 0
        for record in records {
            switch event(record) {
            case .opened: opened += record.count()
            case .canceled: canceled += record.count()
            case .saved, nil: break
            }
        }
        return (opened, max(0, opened - canceled))
    }

    /// A message's (or all messages') stay rate against No Message's, with
    /// the same minimums as a single rate.
    static func groupComparison(_ group: (opened: Int, stayed: Int), against reference: (opened: Int, stayed: Int)) -> ComparisonOutcome {
        AnalyticsStatistics.compare(
            count: group.stayed, total: group.opened, previousCount: reference.stayed, previousTotal: reference.opened,
            minimumTotal: AnalyticsStatistics.minimumTotal, minimumCount: AnalyticsStatistics.minimumCount
        ).outcome
    }

    private enum Event { case opened, canceled, saved }

    private static func event(_ record: ReportRecord) -> Event? {
        let event = record.lower(.event)
        if event.contains("view") { return .opened }
        if event.contains("cancel") { return .canceled }
        if event.contains("save") { return .saved }
        return nil
    }

    static func isNoMessage(_ record: ReportRecord) -> Bool {
        let type = record.lower(.messageType)
        return type.isEmpty || type.contains("no message")
    }

    private static func messages(_ records: [ReportRecord], noMessage: (opened: Int, stayed: Int)) -> [Message] {
        let grouped = Dictionary(grouping: records) { record in
            isNoMessage(record) ? "" : (record[.messageID].isEmpty ? record[.messageName] : record[.messageID])
        }
        return grouped.map { id, records in
            let total = counts(records)
            let first = records.first
            let isNone = id.isEmpty
            let saves = records.filter { event($0) == .saved }
            return Message(
                id: isNone ? "none" : id,
                name: isNone ? String(localized: "No Message") : (first?[.messageName]).flatMap { $0.isEmpty ? nil : $0 } ?? id,
                type: isNone ? "No Message" : records.first { !$0[.messageType].isEmpty }?[.messageType] ?? "",
                isNoMessage: isNone,
                subscriptions: Set(records.map { $0[.subscription] }).filter { !$0.isEmpty }.sorted(),
                territories: Set(records.map { $0[.territory] }).filter { !$0.isEmpty },
                offerName: records.first { !$0[.offerName].isEmpty }?[.offerName],
                opened: total.opened,
                stayed: total.stayed,
                redeemed: saves.filter { $0.lower(.saveType).contains("offer") }.reduce(0) { $0 + $1.count() },
                switched: saves.filter { $0.lower(.saveType).contains("switch") }.reduce(0) { $0 + $1.count() },
                rate: AnalyticsStatistics.rate(count: total.stayed, total: total.opened),
                againstNoMessage: isNone || noMessage.opened == 0 ? nil : groupComparison(total, against: noMessage)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isNoMessage != rhs.isNoMessage { return rhs.isNoMessage }
            return (lhs.rate.fraction ?? 0, rhs.name) > (rhs.rate.fraction ?? 0, lhs.name)
        }
    }

    private static func subscriptions(_ records: [ReportRecord]) -> [SubscriptionRow] {
        Dictionary(grouping: records) { $0[.subscription] }.compactMap { name, records -> SubscriptionRow? in
            let total = counts(records)
            guard !name.isEmpty, total.opened > 0 else { return nil }
            return SubscriptionRow(name: name, opened: total.opened, stayed: total.stayed, rate: AnalyticsStatistics.rate(count: total.stayed, total: total.opened))
        }
        .sorted { ($0.opened, $1.name) > ($1.opened, $0.name) }
    }

    private static func saveTypes(_ records: [ReportRecord]) -> [SaveType] {
        let saves = records.filter { event($0) == .saved }
        let total = saves.reduce(0) { $0 + $1.count() }
        let named: [(String, (String) -> Bool)] = [
            (String(localized: "Redeemed the offer"), { $0.contains("offer") }),
            (String(localized: "Tapped Don’t Cancel"), { $0.contains("cancel") }),
            (String(localized: "Switched plan"), { $0.contains("switch") }),
        ]
        return named.map { name, matches in
            let count = saves.filter { matches($0.lower(.saveType)) }.reduce(0) { $0 + $1.count() }
            return SaveType(name: name, count: count, share: total > 0 ? Double(count) / Double(total) : 0)
        }
    }

    /// Up to eight weeks ending on `through`; a week with fewer than five
    /// people at the cancel screen has no point.
    private static func weeks(_ records: [ReportRecord], through: AnalyticsDay) -> [Week] {
        (0..<chartWeeks).reversed().compactMap { back -> Week? in
            let period = AnalyticsPeriod(ending: through.adding(-7 * back), length: 7)
            let week = records.within(period)
            guard !week.isEmpty else { return nil }
            let with = counts(week.filter { !isNoMessage($0) })
            let without = counts(week.filter(isNoMessage))
            return Week(
                last: period.last,
                withMessage: with.opened >= 5 ? Double(with.stayed) / Double(with.opened) : nil,
                noMessage: without.opened >= 5 ? Double(without.stayed) / Double(without.opened) : nil
            )
        }
    }
}
