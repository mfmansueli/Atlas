//
//  PriceChangeRecord.swift
//  Atlas
//

import Foundation

/// One price change in one territory, and, once Apple's reports cover
/// them, the 28 days before it and the 28 from it, kept so they outlive
/// the Analytics archive's 200 days.
struct PriceChangeRecord: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    /// App Store Connect's resource ID of the subscription or in-app purchase.
    var productID: String
    /// Alpha-3.
    var territoryID: String
    /// When the new price took effect: Apple's start date, the push's
    /// scheduled day, or when Atlas pushed or first saw it.
    var date: Date
    var oldPrice: Decimal
    var newPrice: Decimal
    var currencyCode: String
    var origin: PriceHistoryOrigin
    /// When Atlas recorded it.
    var recordedOn: Date
    /// The push it came from; nil for a change read from App Store Connect.
    var pushID: UUID?
    var before: SalesSignal?
    var after: SalesSignal?

    /// Both 28-day windows are kept.
    var hasWindows: Bool { before != nil && after != nil }

    var day: AnalyticsDay { AnalyticsDay(date) }

    /// The 28 days before the change.
    var beforeRange: ClosedRange<AnalyticsDay> {
        day.adding(-PriceChangeHistory.windowDays)...day.adding(-1)
    }

    /// The 28 days from the change.
    var afterRange: ClosedRange<AnalyticsDay> {
        day...day.adding(PriceChangeHistory.windowDays - 1)
    }

    /// HowSure's evidence, once both windows are kept.
    var priorChange: PriorPriceChange? {
        guard let before, let after else { return nil }
        return PriorPriceChange(date: date, previousPrice: oldPrice, before: before, after: after)
    }
}
