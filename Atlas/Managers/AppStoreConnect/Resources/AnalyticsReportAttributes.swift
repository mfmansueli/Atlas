//
//  AnalyticsReportAttributes.swift
//  Atlas
//

import Foundation

/// `analyticsReports`: one report of a request, e.g. "App Store Discovery
/// and Engagement Standard" in `APP_STORE_ENGAGEMENT`.
struct AnalyticsReportAttributes: Decodable, Hashable, Sendable {
    var name: String?
    var category: String?
}
