//
//  ReportsDownload.swift
//  Atlas
//

import Foundation

/// What one check of the newer reports found: the instances read, and,
/// for each report Apple lists for the app, how many instances it has.
struct ReportsDownload: Hashable, Sendable {
    var batches: [ReportBatch] = []
    /// Reports Apple lists, with their instance count (old ones included).
    var listed: [AppleReportKind: Int] = [:]
}
