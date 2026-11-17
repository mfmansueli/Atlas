//
//  EngagementReportKind.swift
//  Atlas
//

import Foundation

/// The two Apple reports the store-page half of the funnel comes from.
enum EngagementReportKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// "App Store Discovery and Engagement": impressions and page views.
    case engagement
    /// "App Store Downloads": first-time downloads and redownloads.
    case downloads

    /// The category Apple files it under, for `filter[category]`.
    var category: String {
        switch self {
        case .engagement: "APP_STORE_ENGAGEMENT"
        case .downloads: "COMMERCE"
        }
    }

    /// Whether a report's name is this one's. The API names them with a
    /// Standard or Detailed suffix, and only one name is documented, so
    /// they're recognized by what they say.
    func matches(reportName: String) -> Bool {
        let name = reportName.lowercased()
        switch self {
        case .engagement: return name.contains("discovery and engagement")
        case .downloads: return name.contains("download")
        }
    }
}
