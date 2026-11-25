//
//  BreakdownFooterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Break It Down's footer says "Subscriptions aren’t linked" only while
/// nothing links them: Apple's subscription reports name each subscriber's
/// page, so the new columns do.
@Suite("Analytics · Break It Down's footer")
struct BreakdownFooterTests {
    typealias Rows = ReportsTestData

    private var period: AnalyticsPeriod { AnalyticsPeriod(ending: Rows.last, length: 28) }

    private func table(_ dimension: BreakdownDimension, reports: ReportsArchive) -> BreakdownTable {
        var dataset = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        dataset.reports = reports
        return BreakdownTable.make(dataset, dimension: dimension, period: period, context: AnalyticsContext())
    }

    private var subscribers: ReportsArchive {
        Rows.archive([.subscriptionEvents: [
            Rows.event(1, grouping: "Free Trial", subType: "Free Trial Starts", page: "Mood tracking", count: 40),
        ]])
    }

    private var afterDownload: ReportsArchive {
        Rows.archive([.installs: [Rows.install(1, page: "Mood tracking", count: 30)]])
    }

    @Test func withoutTheReportsProductPagesSaySubscriptionsArentLinked() {
        let footer = table(.productPage, reports: ReportsArchive()).footer
        #expect(footer.contains("Subscriptions aren’t linked to a page"))
        #expect(!footer.contains("a sample"))
    }

    @Test func withSubscriberColumnsTheFooterSaysWhereTheyComeFrom() {
        let footer = table(.productPage, reports: subscribers).footer
        #expect(!footer.contains("aren’t linked"))
        #expect(footer.contains("Trials and paid come from Apple’s subscription reports"))
        #expect(footer.contains("Product page test results are in App Store Connect."))
    }

    @Test func afterTheDownloadSaysOnceItsASample() {
        let footer = table(.productPage, reports: afterDownload).footer
        #expect(footer.contains("Deletions and sessions are a sample: only people who share analytics."))
        // No subscription rows: still not linked.
        #expect(footer.contains("Subscriptions aren’t linked to a page"))
    }

    @Test func otherDimensionsKeepTheirOwnLine() {
        let footer = table(.source, reports: subscribers).footer
        #expect(footer.contains("doesn’t split starts and proceeds by source"))
        #expect(footer.contains("Trials and paid come from Apple’s subscription reports"))
        // Apple's newer reports don't split referrers: nothing changes there.
        #expect(BreakdownTable.footer(.referrer, hasSales: true) == table(.referrer, reports: subscribers).footer)
    }
}
