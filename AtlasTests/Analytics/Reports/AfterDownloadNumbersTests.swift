//
//  AfterDownloadNumbersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · after the download")
struct AfterDownloadNumbersTests {
    typealias Rows = ReportsTestData

    private let period = AnalyticsPeriod(ending: ReportsTestData.last, length: 28)

    private var archive: ReportsArchive {
        Rows.archive([
            .installs: [
                Rows.install(2, count: 400),
                Rows.install(2, type: "Redownload", count: 100),
                Rows.install(2, type: "Restore", count: 50),
                Rows.install(3, event: "Delete", type: "", recent: true, count: 60),
                Rows.install(3, event: "Delete", type: "", count: 40),
                Rows.install(2, page: "Mood", count: 200),
                Rows.install(3, event: "Delete", type: "", page: "Mood", recent: true, count: 50),
            ],
            .sessions: [Rows.sessions(1, version: "1.4", sessions: 300, devices: 100)],
            .widgets: [Rows.fact(1, ["iPhone", "US"], [25, 25])],
        ])
    }

    @Test func deletedWithin30DaysIsOfFirstDownloadsAndRedownloads() {
        let numbers = AfterDownloadNumbers.make(archive, period: period) { ReportsArchive.pageName($0, defaultName: "Default") == "Default" }
        // Restores aren't new downloads.
        #expect(numbers.installs == 500)
        #expect(numbers.deletions == 100)
        #expect(numbers.recentDeletions == 60)
        #expect(numbers.deletedWithin30.fraction == 60.0 / 500.0)
    }

    @Test func sessionsAreCountedAWeekPerActiveDevice() {
        let numbers = AfterDownloadNumbers.make(archive, period: period)
        #expect(numbers.sessionsPerWeek == 21)
        #expect(numbers.widgetDevices == 25)
    }

    @Test func aPageThatIsDeletedMoreOftenIsAFinding() {
        var dataset = AnalyticsTestData.lumen
        dataset.reports = archive
        let findings = FindingRules.reportFindings(dataset, now: Date())
        #expect(findings.contains { $0.id == "page.deletes.Mood" })
        #expect(findings.first { $0.id == "page.deletes.Mood" }?.action == .productPage(name: "Mood"))
    }
}
