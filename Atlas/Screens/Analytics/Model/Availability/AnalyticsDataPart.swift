//
//  AnalyticsDataPart.swift
//  Atlas
//

import Foundation

/// The two halves of Analytics' data, which arrive apart: Apple's
/// analytics reports (impressions, page views, downloads) and Sales and
/// Trends (trials, paid starts, proceeds).
enum AnalyticsDataPart: String, Hashable, Sendable {
    case engagement
    case sales
}
