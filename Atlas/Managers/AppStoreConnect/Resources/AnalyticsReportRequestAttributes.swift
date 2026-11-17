//
//  AnalyticsReportRequestAttributes.swift
//  Atlas
//

import Foundation

/// `analyticsReportRequests`: one app's standing request for Apple's
/// analytics reports.
struct AnalyticsReportRequestAttributes: Decodable, Hashable, Sendable {
    /// `ONGOING` or `ONE_TIME_SNAPSHOT`.
    var accessType: String?
    /// Apple stops a request nobody read for a long time; a new one has to
    /// be made.
    var stoppedDueToInactivity: Bool?
}
