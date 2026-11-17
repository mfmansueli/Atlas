//
//  EngagementBatch.swift
//  Atlas
//

import Foundation

/// One downloaded report instance, read: which report, when Apple
/// processed it, and its facts.
struct EngagementBatch: Hashable, Sendable {
    var instanceID: String
    var kind: EngagementReportKind
    /// The Detailed report, which names the product page.
    var isDetailed: Bool
    var processing: AnalyticsDay
    var facts: [EngagementFact]
}
