//
//  ReportProgress.swift
//  Atlas
//

import Foundation

/// Where one of Apple's newer reports stands for one app.
struct ReportProgress: Hashable, Sendable, Codable {
    /// Apple lists the report for the app.
    var isListed = false
    /// Instances Apple has made so far.
    var instances = 0
    /// Rows read across them; 0 with instances is a report sent empty.
    var rows = 0
    /// The newest day with a row.
    var lastDay: AnalyticsDay?

    /// The report's row in Reports from Apple.
    enum State: Hashable, Sendable {
        /// Asked; nothing yet.
        case asked
        /// Apple sent the report, empty.
        case noRows
        case ready(through: AnalyticsDay)
    }

    var state: State {
        if rows > 0, let lastDay { return .ready(through: lastDay) }
        return instances > 0 ? .noRows : .asked
    }
}
