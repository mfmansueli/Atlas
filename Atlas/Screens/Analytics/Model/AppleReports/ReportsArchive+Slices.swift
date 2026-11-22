//
//  ReportsArchive+Slices.swift
//  Atlas
//

import Foundation

/// The newer reports by product page, campaign and source: the rows each
/// slice of Break It Down and Product Pages adds up.
extension ReportsArchive {
    /// Subscribers for the rows `matching` lets through.
    func subscribers(in period: AnalyticsPeriod, matching: (ReportRecord) -> Bool) -> SubscriberCounts {
        LifecycleReport.subscribers(records(.subscriptionEvents).within(period).filter(matching))
    }

    /// Whether Apple sent rows that name a product page, so pages can be told apart.
    var hasPageRows: Bool {
        records(.subscriptionEvents).contains { !$0[.page].isEmpty } || records(.installs).contains { !$0[.page].isEmpty }
    }

    /// A record's product page as the funnel names it: the default page's
    /// rows have no title.
    static func pageName(_ record: ReportRecord, defaultName: String) -> String? {
        let type = record.lower(.pageType)
        guard type.contains("product page") || !record[.page].isEmpty else { return nil }
        return record[.page].isEmpty ? defaultName : record[.page]
    }
}
