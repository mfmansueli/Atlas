//
//  FunnelChartPoint.swift
//  Atlas
//

import Foundation

/// One day on the funnel's chart: a rate (0…1) or, for impressions, a
/// count. nil when the day has nothing to divide by.
struct FunnelChartPoint: Hashable, Sendable, Identifiable {
    var day: AnalyticsDay
    var value: Double?

    var id: AnalyticsDay { day }
}
