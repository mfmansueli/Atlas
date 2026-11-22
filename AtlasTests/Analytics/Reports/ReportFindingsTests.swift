//
//  ReportFindingsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The findings Apple's newer reports add, on the design's Lumen (boards
/// 59–62): retention, billing, an offer, a page and a crashing version.
@Suite("Analytics · findings from the newer reports")
struct ReportFindingsTests {
    private var dataset: AnalyticsDataset {
        var dataset = AnalyticsTestData.lumen
        dataset.reports = DebugReportsData.lumen
        dataset.gracePeriod = DebugReportsData.lumenGracePeriod
        return dataset
    }

    private var findings: [AnalyticsFinding] {
        FindingRules.reportFindings(dataset, now: DebugAnalyticsData.today)
    }

    @Test func theDesignsNumbersAddUp() throws {
        let retention = try #require(RetentionReport.make(DebugReportsData.lumen, days: 28))
        #expect(retention.opened == 412)
        #expect(retention.stayed == 94)
        let period = AnalyticsPeriod(ending: DebugReportsData.last, length: 28)
        let lifecycle = try #require(LifecycleReport.make(DebugReportsData.lumen, period: period))
        #expect(lifecycle.couldNotCharge == 83)
        #expect(lifecycle.recovered == 29)
        #expect(lifecycle.lost == 54)
        let stability = try #require(StabilityReport.make(DebugReportsData.lumen, now: AnalyticsDay(DebugAnalyticsData.today)))
        #expect(stability.latest.version == "1.4")
        #expect((stability.times ?? 0) > 2)
    }

    @Test func billingAsksForTheGracePeriodOnlyWhileItsOff() {
        #expect(findings.contains { $0.id == "billing.gracePeriod" && $0.action == .billing })
        var turnedOn = dataset
        turnedOn.gracePeriod = GracePeriodSetting(id: "grace", isOn: true, duration: .sixteenDays)
        #expect(!FindingRules.reportFindings(turnedOn, now: DebugAnalyticsData.today).contains { $0.id == "billing.gracePeriod" })
        // Unknown isn't off.
        var unknown = dataset
        unknown.gracePeriod = nil
        #expect(!FindingRules.reportFindings(unknown, now: DebugAnalyticsData.today).contains { $0.id == "billing.gracePeriod" })
    }

    @Test func theWeakOfferThePageAndTheCrashesAreFindings() {
        let ids = Set(findings.map(\.id))
        #expect(ids.contains("offer.PODCAST30"))
        #expect(ids.contains("page.deletes.Mood tracking"))
        #expect(!ids.contains("page.deletes.Sleep journal"))
        #expect(ids.contains("stability.crashes.1.4"))
        #expect(!ids.contains("stability.deletions.1.4"))
    }

    @Test func offerMessagesKeepMorePeopleThanTextAlone() {
        #expect(findings.contains { $0.id == "retention.offerMessage" && $0.action == .retention })
    }

    @Test func reportsAloneStillGiveFindings() {
        var empty = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        empty.reports = DebugReportsData.lumen
        empty.gracePeriod = DebugReportsData.lumenGracePeriod
        let findings = FindingRules.findings(empty, context: AnalyticsContext(), now: DebugAnalyticsData.today)
        #expect(findings.contains { $0.id == "stability.crashes.1.4" })
    }

    @Test func emptyReportsGiveNoFindings() {
        var empty = dataset
        empty.reports = ReportsArchive()
        #expect(FindingRules.reportFindings(empty, now: DebugAnalyticsData.today).isEmpty)
    }
}
#endif
