//
//  ResultShortfall.swift
//  Atlas
//

import Foundation

/// Why a territory's result is too few to tell (board 76), said under its
/// pill because each reason asks for something else: "12 starts · needs
/// 30" or "64 page views · needs 100". When more than one threshold is
/// short, the one furthest from met (the lowest share of it) is named,
/// counted on the shorter side of the change.
enum ResultShortfall: Hashable, Sendable {
    /// Fewer than `ResultsEvaluator.minimumStarts` starts on a side.
    case starts(Int)
    /// Fewer than `minimumPageViews` page views on a side.
    case pageViews(Int)
    /// Apple's reports cover fewer than 28 days on a side.
    case days(Int)
    /// More starts than page views on a side (offer codes, the web), so
    /// the rate means nothing.
    case startsOutsidePage

    /// Analytics' floor for comparing two periods.
    static var minimumPageViews: Int { AnalyticsStatistics.minimumComparedTotal }

    /// What keeps `before` and `after` from a verdict; nil when nothing does.
    static func of(before: SalesWindow, after: SalesWindow) -> ResultShortfall? {
        let starts = min(before.starts, after.starts)
        let views = min(before.pageViews, after.pageViews)
        let days = min(before.days, after.days)
        // Starts first on a tie: they're what a result counts.
        let candidates: [(ResultShortfall, Double)] = [
            (.starts(starts), share(starts, of: ResultsEvaluator.minimumStarts)),
            (.pageViews(views), share(views, of: minimumPageViews)),
            (.days(days), share(days, of: ResultsEvaluator.windowDays)),
        ]
        if let furthest = candidates.filter({ $0.1 < 1 }).min(by: { $0.1 < $1.1 }) {
            return furthest.0
        }
        if before.starts > before.pageViews || after.starts > after.pageViews { return .startsOutsidePage }
        return nil
    }

    /// "12 starts · needs 30", "64 page views · needs 100", "21 days · needs 28".
    var text: String {
        switch self {
        case let .starts(count):
            let needed = ResultsEvaluator.minimumStarts
            return count == 1
                ? String(localized: "1 start · needs \(needed)", comment: "kind:label")
                : String(localized: "\(PricingText.grouped(count)) starts · needs \(needed)", comment: "kind:label")
        case let .pageViews(count):
            let needed = Self.minimumPageViews
            return count == 1
                ? String(localized: "1 page view · needs \(needed)", comment: "kind:label")
                : String(localized: "\(PricingText.grouped(count)) page views · needs \(needed)", comment: "kind:label")
        case let .days(count):
            let needed = ResultsEvaluator.windowDays
            return count == 1
                ? String(localized: "1 day · needs \(needed)", comment: "kind:label")
                : String(localized: "\(count) days · needs \(needed)", comment: "kind:label")
        case .startsOutsidePage:
            return String(localized: "More starts than page views", comment: "kind:label")
        }
    }

    private static func share(_ count: Int, of needed: Int) -> Double {
        needed > 0 ? Double(max(count, 0)) / Double(needed) : 1
    }
}
