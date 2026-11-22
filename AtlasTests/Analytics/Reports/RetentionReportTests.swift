//
//  RetentionReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · Retention Messaging")
struct RetentionReportTests {
    typealias Rows = ReportsTestData

    /// 100 opened Before you go (40 stayed), 100 saw No Message (10 stayed),
    /// complete days only; 9 more opened in the 4 days still arriving.
    private var archive: ReportsArchive {
        var facts: [ReportFact] = []
        for back in 4..<14 {
            facts.append(Rows.retention(back, event: "Page views", count: 10))
            facts.append(Rows.retention(back, event: "Cancels", count: 6))
            facts.append(Rows.retention(back, event: "Saves", saveType: "Redeem offer", count: 3))
            facts.append(Rows.retention(back, event: "Saves", saveType: "Don’t cancel", count: 1))
            facts.append(Rows.retention(back, event: "Page views", type: "No Message", name: "", id: "", count: 10))
            facts.append(Rows.retention(back, event: "Cancels", type: "No Message", name: "", id: "", count: 9))
        }
        facts += (0..<4).map { Rows.retention($0, event: "Page views", count: 3) }
        return Rows.archive([.retention: facts])
    }

    @Test func theSaveRateCountsOnlyCompleteDays() throws {
        let report = try #require(RetentionReport.make(archive, days: 28))
        #expect(report.period.last == Rows.last.adding(-4))
        #expect(report.opened == 200)
        #expect(report.stayed == 50)
        #expect(report.canceled == 150)
        #expect(report.rate.fraction == 0.25)
        #expect(report.lastDay == Rows.last)
    }

    @Test func eachMessageIsComparedWithNoMessage() throws {
        let report = try #require(RetentionReport.make(archive, days: 28))
        #expect(report.messages.map(\.name) == ["Before you go", "No Message"])
        let message = report.messages[0]
        #expect(message.opened == 100)
        #expect(message.stayed == 40)
        #expect(message.redeemed == 30)
        #expect(message.againstNoMessage?.isHigher == true)
        #expect(report.messages[1].isNoMessage)
        #expect(report.messages[1].againstNoMessage == nil)
        #expect(report.withAgainstWithout.isHigher)
    }

    @Test func savesAreSplitByHowPeopleStayed() throws {
        let report = try #require(RetentionReport.make(archive, days: 28))
        let byName = Dictionary(uniqueKeysWithValues: report.saveTypes.map { ($0.name, $0.count) })
        #expect(byName[String(localized: "Redeemed the offer")] == 30)
        #expect(byName[String(localized: "Tapped Don’t Cancel")] == 10)
        #expect(byName[String(localized: "Switched plan")] == 0)
    }

    @Test func fewPeopleAtTheCancelScreenAreTooFewToTell() throws {
        // A newer day Apple hasn't completed yet: the last 4 days are left
        // out, so the 14 views five days back are inside the period.
        let facts = [
            Rows.retention(5, event: "Page views", count: 14), Rows.retention(5, event: "Cancels", count: 11),
            Rows.retention(0, event: "Page views", count: 2),
        ]
        let report = try #require(RetentionReport.make(Rows.archive([.retention: facts]), days: 28))
        #expect(report.rate.measured == nil)
        #expect(report.stayed == 3)
    }

    @Test func noRowsMakeNoReport() {
        #expect(RetentionReport.make(ReportsArchive(), days: 28) == nil)
    }
}
