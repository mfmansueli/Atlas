//
//  ReportsTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Archives of Apple's newer reports, a few rows at a time.
enum ReportsTestData {
    static let last = AnalyticsTestData.through

    /// One row: `values` in the kind's dimension order, `counts` in its
    /// measure order.
    static func fact(_ back: Int = 0, _ values: [String], _ counts: [Int]) -> ReportFact {
        ReportFact(day: last.adding(-back), values: values, counts: counts)
    }

    static func archive(_ facts: [AppleReportKind: [ReportFact]], listed: [AppleReportKind: Int] = [:]) -> ReportsArchive {
        var download = ReportsDownload()
        download.listed = listed
        for (kind, list) in facts {
            download.listed[kind] = max(download.listed[kind] ?? 0, 1)
            download.batches.append(ReportBatch(instanceID: "test-\(kind.rawValue)", kind: kind, processing: last, facts: ReportFact.merged(list)))
        }
        var archive = ReportsArchive()
        archive.apply(download, now: Date(timeIntervalSince1970: 1_790_000_000))
        return archive
    }

    /// A Retention Messaging row: event, subscription, type, name, id, offer, suggested, save type, device, territory.
    static func retention(_ back: Int, event: String, type: String = "Text message", name: String = "Before you go", id: String = "rm-1",
                          saveType: String = "", count: Int) -> ReportFact
    {
        fact(back, [event, "Pro Monthly", type, name, id, "", "", saveType, "iPhone", "US"], [count])
    }

    /// A Subscription Event row, by grouping, sub type, offer and page.
    static func event(
        _ back: Int, grouping: String, subType: String, offerType: String = "", offer: String = "", duration: String = "", plan: String = "",
        reason: String = "", campaign: String = "", page: String = "", count: Int
    ) -> ReportFact {
        let values = [
            grouping, subType, "Pro Monthly", offerType, offer, duration, plan, reason, "App Store Search", "", campaign, "Product page", page, "iPhone", "US",
        ]
        return fact(back, values, [count])
    }

    /// App Sessions: version, device, source, referrer, campaign, page type, page, territory; sessions, duration, devices.
    static func sessions(_ back: Int, version: String, device: String = "iPhone", page: String = "", sessions: Int, devices: Int = 0) -> ReportFact {
        fact(back, [version, device, "App Store Search", "", "", "Product page", page, "US"], [sessions, sessions * 200, devices])
    }

    static func crashes(_ back: Int, version: String, device: String = "iPhone", count: Int) -> ReportFact {
        fact(back, [version, device], [count, count])
    }

    /// Installations and Deletions: event, download type, version, device, source, referrer, campaign, page type, page, recent, territory.
    static func install(
        _ back: Int, event: String = "Install", type: String = "First-time download", page: String = "", recent: Bool = false, count: Int
    ) -> ReportFact {
        fact(back, [event, type, "1.4", "iPhone", "App Store Search", "", "", "Product page", page, recent ? "1" : "", "US"], [count, count])
    }
}
