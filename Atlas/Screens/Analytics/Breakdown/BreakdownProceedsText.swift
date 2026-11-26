//
//  BreakdownProceedsText.swift
//  Atlas
//

import Foundation

/// The proceeds banner's words (board 92), when Break It Down opens from
/// the Overview's Proceeds number: what proceeds are, the total in the
/// period, and the territories that brought the most.
enum BreakdownProceedsText {
    static var title: String {
        String(localized: "Where the proceeds come from.", comment: "kind:banner · Break It Down from the Proceeds number")
    }

    static var whereToLook: String {
        String(
            localized: "The Proceeds column is on the right; the total is in the All territories row.",
            comment: "kind:banner · Break It Down from the Proceeds number"
        )
    }

    /// "What’s left after Apple’s commission and taxes, per territory:
    /// $6,040 in the last 28 days. Germany brought $1,810 (30%), then the
    /// United States and Japan $900 and $700." nil without proceeds.
    static func explanation(_ table: BreakdownTable) -> String? {
        guard table.dimension == .territory, let total = table.totals.proceeds else { return nil }
        let days = table.period.length
        let lead = String(
            localized: "What’s left after Apple’s commission and taxes, per territory: \(AnalyticsText.dollars(total)) in the last \(days) days.",
            comment: "kind:banner · Break It Down from the Proceeds number"
        )
        let top = table.rows
            .compactMap { row in row.totals.proceeds.flatMap { $0 > 0 ? (name: row.name, amount: $0) : nil } }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
        guard let first = top.first else { return lead }
        let share = total > 0 ? (first.amount as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue : 0
        let brought = String(
            localized: "\(first.name) brought \(AnalyticsText.dollars(first.amount)) (\(AnalyticsText.wholePercent(share)))",
            comment: "kind:banner · Break It Down from the Proceeds number"
        )
        return "\(lead) \(sentence(brought: brought, rest: Array(top.dropFirst())))"
    }

    /// "Germany brought $1,810 (30%)", then the next one or two.
    private static func sentence(brought: String, rest: [(name: String, amount: Decimal)]) -> String {
        guard let second = rest.first else { return "\(brought)." }
        guard rest.count > 1 else {
            return String(
                localized: "\(brought), then \(second.name) \(AnalyticsText.dollars(second.amount)).",
                comment: "kind:banner · Break It Down from the Proceeds number"
            )
        }
        let third = rest[1]
        if second.amount == third.amount {
            return String(
                localized: "\(brought), then \(second.name) and \(third.name) \(AnalyticsText.dollars(second.amount)) each.",
                comment: "kind:banner · Break It Down from the Proceeds number"
            )
        }
        return String(
            localized: "\(brought), then \(second.name) and \(third.name) \(AnalyticsText.dollars(second.amount)) and \(AnalyticsText.dollars(third.amount)).",
            comment: "kind:banner · Break It Down from the Proceeds number"
        )
    }
}
