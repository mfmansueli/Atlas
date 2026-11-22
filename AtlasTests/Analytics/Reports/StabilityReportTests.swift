//
//  StabilityReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · crashes by version")
struct StabilityReportTests {
    typealias Rows = ReportsTestData

    /// 1.3 and 1.4 side by side for 20 days; 1.4 crashes `newRate` per 1,000.
    private func archive(newCrashesPerDay: Int, days: Int = 20) -> ReportsArchive {
        var sessions: [ReportFact] = []
        var crashes: [ReportFact] = []
        for back in 0..<days {
            sessions.append(Rows.sessions(back, version: "1.3", sessions: 2000, devices: 600))
            sessions.append(Rows.sessions(back, version: "1.4", sessions: 1000, devices: 300))
            crashes.append(Rows.crashes(back, version: "1.3", count: 2))
            crashes.append(Rows.crashes(back, version: "1.4", count: newCrashesPerDay))
        }
        return Rows.archive([.sessions: sessions, .crashes: crashes])
    }

    @Test func aVersionThatCrashesMoreIsWorse() throws {
        let report = try #require(StabilityReport.make(archive(newCrashesPerDay: 3), now: Rows.last))
        #expect(report.latest.version == "1.4")
        #expect(report.previous?.version == "1.3")
        // Up to 14 shared days, ending 5 days before today.
        #expect(report.period.length == StabilityReport.comparedDays)
        #expect(report.period.last == Rows.last.adding(-5))
        #expect(report.latest.perThousand == 3)
        #expect(report.previous?.perThousand == 1)
        #expect(report.times == 3)
        #expect(report.isWorse)
        #expect(report.headline != nil)
    }

    @Test func theSameCrashRateIsNotAnAlert() throws {
        let report = try #require(StabilityReport.make(archive(newCrashesPerDay: 1), now: Rows.last))
        #expect(!report.isWorse)
        #expect(report.headline == nil)
    }

    @Test func versionsAreOrderedByNumberNotText() {
        #expect(AppVersionOrder.isBefore("1.9", "1.10"))
        #expect(AppVersionOrder.isBefore("2.0", "2.0.1"))
        #expect(!AppVersionOrder.isBefore("1.10", "1.9"))
    }

    @Test func noSessionsMakeNoReport() {
        #expect(StabilityReport.make(ReportsArchive(), now: Rows.last) == nil)
    }
}
