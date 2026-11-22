//
//  ReportBatch.swift
//  Atlas
//

import Foundation

/// One downloaded instance of a newer report, read.
struct ReportBatch: Hashable, Sendable {
    var instanceID: String
    var kind: AppleReportKind
    var processing: AnalyticsDay
    var facts: [ReportFact]
}
