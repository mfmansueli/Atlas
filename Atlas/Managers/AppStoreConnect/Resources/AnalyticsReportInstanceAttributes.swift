//
//  AnalyticsReportInstanceAttributes.swift
//  Atlas
//

import Foundation

/// `analyticsReportInstances`: one processed file set of a report.
struct AnalyticsReportInstanceAttributes: Decodable, Hashable, Sendable {
    /// `DAILY`, `WEEKLY` or `MONTHLY`.
    var granularity: String?
    /// "2026-11-09": a later one replaces an earlier one's days.
    var processingDate: String?
}
