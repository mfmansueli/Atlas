//
//  BreakdownRow.swift
//  Atlas
//

import Foundation

/// One line of the breakdown: a territory, language, source, device or
/// product page, with its counts and its rates against the app's average.
struct BreakdownRow: Hashable, Sendable, Identifiable {
    /// The territory's alpha-2, the locale code, or the name.
    var id: String
    var name: String
    /// The region for the flag; nil without one.
    var regionCode: String?
    /// A second line: the language a territory sees, what a source is.
    var detail: String?
    var totals: FunnelTotals
    var viewRate: AnalyticsRate
    var downloadRate: AnalyticsRate
    var startRate: AnalyticsRate

    func rate(_ column: BreakdownColumn) -> AnalyticsRate? {
        switch column {
        case .viewRate: viewRate
        case .downloadRate: downloadRate
        case .startRate: startRate
        default: nil
        }
    }

    /// What a column sorts by; rows without a value go last.
    func sortValue(_ column: BreakdownColumn) -> Double? {
        switch column {
        case .name: nil
        case .impressions: totals.impressions.map(Double.init)
        case .pageViews: totals.pageViews.map(Double.init)
        case .viewRate: viewRate.fraction
        case .downloads: totals.downloads.map(Double.init)
        case .downloadRate: downloadRate.fraction
        case .starts: totals.starts.map(Double.init)
        case .startRate: startRate.fraction
        case .proceeds: totals.proceeds.map { NSDecimalNumber(decimal: $0).doubleValue }
        }
    }
}
