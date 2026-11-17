//
//  FunnelTotals.swift
//  Atlas
//

import Foundation

/// The funnel's counts over some days, for everything or one slice. A nil
/// count is one Apple didn't give.
struct FunnelTotals: Hashable, Sendable {
    var impressions: Int?
    var pageViews: Int?
    var downloads: Int?
    var trials: Int?
    var paid: Int?
    /// Subscription starts: trials begun plus direct purchases.
    var starts: Int?
    /// After Apple's commission and taxes, in US dollars.
    var proceeds: Decimal?

    func count(_ stage: FunnelStage) -> Int? {
        switch stage {
        case .impressions: impressions
        case .pageViews: pageViews
        case .downloads: downloads
        case .trials: trials
        case .paid: paid
        }
    }

    /// The step's rate from the one before, against `average`.
    func rate(_ stage: FunnelStage, average: Double? = nil) -> AnalyticsRate {
        guard let previous = stage.previous else { return .missing }
        return AnalyticsStatistics.rate(count: count(stage), total: count(previous), average: average)
    }

    /// The plain fraction of a step, nil without both counts.
    func fraction(_ stage: FunnelStage) -> Double? {
        guard let previous = stage.previous, let count = count(stage), let total = self.count(previous), total > 0 else { return nil }
        return Double(count) / Double(total)
    }

    /// Subscription starts per download.
    func startRate(average: Double? = nil) -> AnalyticsRate {
        AnalyticsStatistics.rate(count: starts, total: downloads, average: average)
    }

    var startFraction: Double? {
        guard let starts, let downloads, downloads > 0 else { return nil }
        return Double(starts) / Double(downloads)
    }
}
