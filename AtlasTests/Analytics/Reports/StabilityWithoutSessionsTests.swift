//
//  StabilityWithoutSessionsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Apple sent App Crashes without App Sessions: Stability still shows,
/// with the counts and no rate (README-An2).
@Suite("Analytics · crashes without sessions")
struct StabilityWithoutSessionsTests {
    typealias Rows = ReportsTestData

    private func crashesOnly(days: Int = 20) -> ReportsArchive {
        var crashes: [ReportFact] = []
        for back in 0..<days {
            crashes.append(Rows.crashes(back, version: "1.3", count: 2))
            crashes.append(Rows.crashes(back, version: "1.4", device: "iPad", count: 5))
        }
        return Rows.archive([.crashes: crashes])
    }

    @Test func crashesAloneMakeAReportOfCounts() throws {
        let report = try #require(StabilityReport.make(crashesOnly(), now: Rows.last))
        #expect(!report.hasSessions)
        #expect(report.latest.version == "1.4")
        #expect(report.previous?.version == "1.3")
        // 14 compared days, ending 5 days before today.
        #expect(report.latest.crashes == 5 * StabilityReport.comparedDays)
        #expect(report.previous?.crashes == 2 * StabilityReport.comparedDays)
        #expect(report.latest.perThousand == nil)
        #expect(report.times == nil)
    }

    @Test func withoutSessionsThereIsNoVerdictOrAlert() throws {
        let report = try #require(StabilityReport.make(crashesOnly(), now: Rows.last))
        #expect(report.verdict == "No rate without sessions")
        #expect(!report.isWorse)
        #expect(report.headline == nil)
        #expect(report.mostAffected == nil)
    }

    @Test func devicesShowTheirCrashesWithNoChange() throws {
        let report = try #require(StabilityReport.make(crashesOnly(), now: Rows.last))
        #expect(report.devices.map(\.device) == ["iPad"])
        #expect(report.devices.first?.latest.crashes == 5 * StabilityReport.comparedDays)
        #expect(report.devices.first?.changeText == "—")
    }

    @Test func crashesWithoutSessionsGiveNoFinding() {
        var dataset = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        dataset.reports = crashesOnly()
        let findings = FindingRules.reportFindings(dataset, now: .now)
        #expect(!findings.contains { $0.id.hasPrefix("stability.") })
    }

    @Test func sessionsStillDecideTheDaysWhenTheyArrive() throws {
        var sessions: [ReportFact] = []
        var crashes: [ReportFact] = []
        for back in 0..<20 {
            sessions.append(Rows.sessions(back, version: "1.3", sessions: 2000, devices: 600))
            sessions.append(Rows.sessions(back, version: "1.4", sessions: 1000, devices: 300))
            crashes.append(Rows.crashes(back, version: "1.4", count: 3))
        }
        let report = try #require(StabilityReport.make(Rows.archive([.sessions: sessions, .crashes: crashes]), now: Rows.last))
        #expect(report.hasSessions)
        #expect(report.latest.perThousand == 3)
    }
}
