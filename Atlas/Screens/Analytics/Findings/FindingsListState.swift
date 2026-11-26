//
//  FindingsListState.swift
//  Atlas
//

import Foundation

/// What What to Try shows (board 92): the findings, or, when there are
/// none yet, why (a small ContentUnavailableView, README-DS §14).
enum FindingsListState: Hashable, Sendable {
    /// Fewer than 28 days of data: `days` so far; the first findings come
    /// around `firstOn`, when it's known.
    case notYet(days: Int, firstOn: Date?)
    /// Too few page views for any rate to tell.
    case tooQuiet
    /// 28 days or more, and nothing worth changing: every step is near the
    /// app's average.
    case nothingStandsOut
    /// The findings, in the filter's list: new, waiting for a push, acted
    /// on, dismissed.
    case list

    /// Findings compare full periods of this many days.
    static let fullPeriod = 28

    /// The state from what Analytics knows: the days of data, whether the
    /// funnel is too quiet for rates, and how many findings exist at all
    /// (open, acted on or dismissed).
    static func make(dayCount: Int, firstDay: AnalyticsDay?, isQuiet: Bool, findingCount: Int) -> FindingsListState {
        if findingCount > 0 { return .list }
        if dayCount < fullPeriod { return .notYet(days: dayCount, firstOn: firstDay.map { $0.adding(fullPeriod).date }) }
        if isQuiet { return .tooQuiet }
        return .nothingStandsOut
    }

    var title: String {
        String(localized: "No findings yet", comment: "kind:empty-state · What to Try")
    }

    /// The sentence under the title, about `appName`.
    func text(appName: String) -> String? {
        switch self {
        case let .notYet(days, firstOn?):
            String(
                localized: "Findings need a full 28 days to compare. \(appName) has \(days); the first ones come around \(AnalyticsText.day(firstOn)).",
                comment: "kind:empty-state · What to Try"
            )
        case .notYet:
            String(localized: "Findings need a full 28 days to compare.", comment: "kind:empty-state · What to Try")
        case .tooQuiet:
            String(
                localized: "\(appName) has too few page views to tell. Findings start at about 100 a month.",
                comment: "kind:empty-state · What to Try"
            )
        case .nothingStandsOut:
            String(localized: "Nothing stands out: every step is near \(appName)’s average.", comment: "kind:empty-state · What to Try")
        case .list:
            nil
        }
    }
}
