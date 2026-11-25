//
//  BreakdownRowTrend.swift
//  Atlas
//

import Foundation

/// The inspector's small chart: one row's page views per impression over
/// the last 90 days, each day the rate of the 7 days ending there (a single
/// day of a small territory moves by chance), against the whole app's rate
/// over the same days.
struct BreakdownRowTrend: Hashable, Sendable {
    struct Point: Hashable, Sendable, Identifiable {
        var day: AnalyticsDay
        var rate: Double?

        var id: Int { day.number }
    }

    static let days = 90
    static let window = 7
    /// Fewer impressions than this in a week leaves that day's rate out.
    static let minimumImpressions = 50

    var points: [Point]
    /// The whole app's page views per impression over the same days.
    var average: Double?

    /// The facts behind `row`, for the dimensions whose rows are filters.
    static func filter(for row: BreakdownRow, dimension: BreakdownDimension, context: AnalyticsContext) -> FactFilter? {
        switch dimension {
        case .territory: FactFilter(territories: [row.id])
        case .source: FactFilter(source: row.id)
        case .device: FactFilter(device: row.id)
        case .language:
            context.territories(showing: [row.id]).isEmpty ? nil : FactFilter(territories: context.territories(showing: [row.id]))
        case .productPage, .referrer, .campaign: nil
        }
    }

    /// nil when there's too little to draw: under two weeks of rates.
    static func make(_ dataset: AnalyticsDataset, filter: FactFilter) -> BreakdownRowTrend? {
        guard let through = dataset.through else { return nil }
        let first = through.adding(-(days + window - 2))
        var impressions: [AnalyticsDay: Int] = [:]
        var views: [AnalyticsDay: Int] = [:]
        var allImpressions = 0
        var allViews = 0
        let shownFrom = through.adding(-(days - 1))
        for fact in dataset.engagement where fact.day >= first && fact.day <= through {
            if fact.day >= shownFrom {
                allImpressions += fact.impressions
                allViews += fact.pageViews
            }
            guard filter.matches(fact) else { continue }
            impressions[fact.day, default: 0] += fact.impressions
            views[fact.day, default: 0] += fact.pageViews
        }
        let points = (0..<days).map { offset -> Point in
            let day = through.adding(offset - (days - 1))
            let week = (0..<window).map { day.adding(-$0) }
            let shown = week.reduce(0) { $0 + (impressions[$1] ?? 0) }
            let opened = week.reduce(0) { $0 + (views[$1] ?? 0) }
            return Point(day: day, rate: shown >= minimumImpressions ? Double(opened) / Double(shown) : nil)
        }
        guard points.count(where: { $0.rate != nil }) >= 14 else { return nil }
        return BreakdownRowTrend(points: points, average: allImpressions > 0 ? Double(allViews) / Double(allImpressions) : nil)
    }
}
