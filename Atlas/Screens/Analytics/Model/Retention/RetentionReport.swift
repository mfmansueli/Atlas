//
//  RetentionReport.swift
//  Atlas
//

import Foundation

/// What happens when people tap Cancel Subscription, from Apple's
/// Retention Messaging report: how many opened the cancel screen, how many
/// stayed, and each message against No Message. Only complete days count:
/// Apple completes a day up to 4 days later.
struct RetentionReport: Hashable, Sendable {
    /// One retention message (or No Message), across its languages.
    struct Message: Hashable, Sendable, Identifiable {
        /// Apple's message identifier, else its name.
        var id: String
        var name: String
        /// Apple's Retention Message Type, e.g. "Text message with offer".
        var type: String
        var isNoMessage: Bool
        var subscriptions: [String]
        var territories: Set<String>
        var offerName: String?
        var opened: Int
        var stayed: Int
        /// How many redeemed its offer or switched plan.
        var redeemed: Int
        var switched: Int
        var rate: AnalyticsRate
        /// Against No Message; nil for No Message itself or when it has no rows.
        var againstNoMessage: ComparisonOutcome?

        var typeTitle: String { RetentionReport.typeTitle(type) }
    }

    struct SubscriptionRow: Hashable, Sendable, Identifiable {
        var name: String
        var opened: Int
        var stayed: Int
        var rate: AnalyticsRate

        var id: String { name }
    }

    /// How people stayed: redeemed the offer, switched plan, tapped Don't Cancel.
    struct SaveType: Hashable, Sendable, Identifiable {
        var name: String
        var count: Int
        var share: Double

        var id: String { name }
    }

    /// One week's save rate, with a message and with none.
    struct Week: Hashable, Sendable, Identifiable {
        var last: AnalyticsDay
        var withMessage: Double?
        var noMessage: Double?

        var id: Int { last.number }
    }

    /// Complete days only.
    var period: AnalyticsPeriod
    /// The newest day Apple has sent; days after `period.last` are still
    /// arriving.
    var lastDay: AnalyticsDay
    var opened: Int
    var stayed: Int
    var rate: AnalyticsRate
    var comparison: PeriodComparison?
    var withMessage: AnalyticsRate
    var withMessageStayed: Int
    var withMessageOpened: Int
    var noMessage: AnalyticsRate
    var noMessageStayed: Int
    var noMessageOpened: Int
    /// Whether a message keeps more people than none.
    var withAgainstWithout: ComparisonOutcome
    var messages: [Message]
    var subscriptions: [SubscriptionRow]
    var saveTypes: [SaveType]
    var weeks: [Week]

    var canceled: Int { opened - stayed }
    var saves: Int { saveTypes.reduce(0) { $0 + $1.count } }

    /// Days Apple hasn't completed yet: after `period.last`, up to `lastDay`.
    var arriving: AnalyticsPeriod? {
        lastDay > period.last ? AnalyticsPeriod(first: period.last.adding(1), last: lastDay) : nil
    }

    var isTooFew: Bool { rate.isTooFew }
    var isEmpty: Bool { opened == 0 }

    /// Apple's message types, as Atlas writes them.
    static func typeTitle(_ type: String) -> String {
        let value = type.lowercased()
        if value.contains("no message") || value.isEmpty { return String(localized: "Apple’s plain screen") }
        if value.contains("offer") { return String(localized: "Text with offer") }
        if value.contains("switch plan") { return String(localized: "Text with switch plan") }
        if value.contains("with image") { return String(localized: "Text with image") }
        return String(localized: "Text message")
    }
}
