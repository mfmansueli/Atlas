//
//  MeasuredChange.swift
//  Atlas
//

import Foundation

/// One thing pushed from Atlas, as Analytics marks it on the
/// timeline and measures it: 28 days before against 28 days after.
struct MeasuredChange: Hashable, Sendable, Identifiable {
    var id: String
    var date: Date
    var kind: ChangeKind
    /// "Subtitle · English (U.S.)", "Screenshots · 8 languages".
    var title: String
    /// The store page languages it changed.
    var localeCodes: [String]
    /// One text's old and new value, when the push changed just one.
    var oldValue: String?
    var newValue: String?

    var day: AnalyticsDay { AnalyticsDay(date) }
    var stage: FunnelStage? { kind.stage }
    /// The chip on the timeline.
    var shortTitle: String {
        switch kind {
        case .searchText, .pageText: String(localized: "Store Page")
        case .screenshots: String(localized: "Screenshots")
        case .prices: String(localized: "Prices")
        case .inAppTexts: String(localized: "Paywall")
        }
    }

    /// "Tap-through from search", "Page views per impression"…
    var stageTitle: String {
        switch kind {
        case .searchText: String(localized: "Tap-through from search")
        case .prices: String(localized: "Starts and proceeds, per country")
        default: stage?.rateTitle ?? ""
        }
    }
}
