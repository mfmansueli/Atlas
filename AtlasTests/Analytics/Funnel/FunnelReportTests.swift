//
//  FunnelReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the funnel")
struct FunnelReportTests {
    private typealias Data = AnalyticsTestData

    @Test func everyStepHasItsCountRateAndChange() throws {
        let report = try #require(FunnelReport.make(Data.lumen, days: 28))
        #expect(report.steps.map(\.stage) == FunnelStage.allCases)
        #expect(report.steps.map(\.count) == [184_200, 9870, 3120, 412, 168])
        #expect(report.steps.map(\.change) == ["+7%", "−5%", "−2%", "+4%", "−5%"])
        #expect(report.period.last == Data.through)
        #expect(report.previous?.length == 28)
        #expect(!report.isNew)
        let views = try #require(report.step(.pageViews))
        #expect(views.rate.text == AnalyticsText.percent(9870.0 / 184_200))
        #expect(views.comparison?.outcome == .lower(.sure))
        #expect(report.step(.impressions)?.rate == .missing)
        #expect(report.step(.downloads)?.comparison?.outcome == .higher(.fairlySure))
        #expect(report.totals.proceeds == 4920)
    }

    @Test func theBiggestLossIsSaidInWords() throws {
        let change = MeasuredChange(id: "c", date: Data.through.adding(-19).date, kind: .screenshots, title: "New screenshots", localeCodes: ["en-US"])
        let report = try #require(FunnelReport.make(Data.lumen, days: 28, changes: [change]))
        #expect(report.worstStep?.stage == .pageViews)
        #expect(report.callout.kind == .loss(.pageViews))
        #expect(report.callout.title == "Biggest loss: page views per impression")
        #expect(report.callout.text.contains(AnalyticsText.percent(9870.0 / 184_200)))
        #expect(report.callout.text.contains(AnalyticsText.percent(10420.0 / 171_900)))
        #expect(report.callout.actions == [.seeChange("c"), .breakDown(.source)])
    }

    @Test func nothingWorseSaysSo() throws {
        var dataset = Data.lumen
        dataset.engagement[1] = Data.fact(back: 28, impressions: 184_200, views: 9870, downloads: 3120)
        dataset.events = []
        let report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.callout.kind == .steady)
        #expect(report.callout.title == "No step is worse than before")
    }

    @Test func aStepSaysWhyItHasNoNumber() throws {
        var dataset = Data.lumen
        dataset.salesState = .needsVendorNumber
        var report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.step(.trials)?.gap == .needsVendorNumber)
        #expect(report.step(.trials)?.count == nil)
        #expect(report.step(.trials)?.countText == "—")
        #expect(report.step(.paid)?.rate == .missing)
        #expect(report.step(.downloads)?.count == 3120)
        #expect(report.noteIsWarning)
        #expect(report.note?.contains("vendor number") == true)
        #expect(FunnelGap.needsVendorNumber.actionTitle == "Add Vendor Number…")

        dataset.salesState = .keyCannotRead
        report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.step(.paid)?.gap == .keyCannotReadSales)

        dataset.salesState = .ready
        dataset.engagement = []
        dataset.engagementState = .waiting(asked: nil)
        report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.step(.impressions)?.gap == .engagementWaiting(asked: nil))
        // Trials need downloads to divide by.
        #expect(report.step(.trials)?.count == 412)
        #expect(report.step(.trials)?.rate == .missing)
    }

    @Test func anAppWithoutASubscriptionEndsAtDownloads() throws {
        var dataset = Data.lumen
        dataset.sellsSubscriptions = false
        dataset.engagement[1] = Data.fact(back: 28, impressions: 184_200, views: 9870, downloads: 3120)
        let report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.steps.map(\.stage) == [.impressions, .pageViews, .downloads])
        #expect(report.callout.kind == .noSubscription)
        #expect(report.note == nil)
    }

    @Test func aNewAppShowsCountsWithoutVerdicts() throws {
        var dataset = Data.lumen
        dataset.engagement = [Data.fact(impressions: 3100, views: 240, downloads: 61), Data.fact(back: 8, impressions: 10)]
        dataset.events = [Data.event(.trialStart, 4)]
        let report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.isNew)
        #expect(report.previous == nil)
        #expect(report.period.length == 9)
        #expect(report.callout.kind == .newApp)
        #expect(report.callout.title == "Lumen Journal has 9 days of data")
        #expect(report.steps.allSatisfy { $0.comparison == nil && $0.change == nil })
        #expect(report.rangeText.contains("no earlier period"))
    }

    @Test func almostNoTrafficIsTooFewToTell() throws {
        var dataset = Data.lumen
        dataset.engagement = [
            Data.fact(impressions: 380, views: 21, downloads: 4), Data.fact(back: 28, impressions: 410, views: 26, downloads: 6),
            Data.fact(back: 60, impressions: 1),
        ]
        dataset.events = []
        let report = try #require(FunnelReport.make(dataset, days: 28))
        #expect(report.callout.kind == .tooFew)
        #expect(report.step(.downloads)?.rate == .tooFew(count: 4, total: 21))
        #expect(report.step(.downloads)?.rate.text == "4 of 21")
    }

    @Test func noDataMakesNoReport() {
        #expect(FunnelReport.make(AnalyticsDataset(appID: "1", appName: "Empty"), days: 28) == nil)
    }

    // MARK: - Chart

    @Test func theChartRunsOverBothPeriodsWithItsMarks() throws {
        let change = MeasuredChange(id: "c", date: Data.through.adding(-19).date, kind: .screenshots, title: "New screenshots", localeCodes: [])
        let old = MeasuredChange(id: "old", date: Data.through.adding(-200).date, kind: .pageText, title: "Old", localeCodes: [])
        let report = try #require(FunnelReport.make(Data.lumen, days: 28))
        let chart = FunnelChart.make(Data.lumen, report: report, stage: .pageViews, changes: [change, old])
        #expect(chart.points.count == 56)
        #expect(chart.currentStart == 28)
        #expect(chart.hasPrevious)
        #expect(chart.marks.map(\.id) == ["c"])
        #expect(chart.points.last?.value.map { ($0 * 1000).rounded() } == 54)
        #expect(!chart.isEmpty)
        #expect(chart.minimum < chart.maximum)
    }

    @Test func aStepWithoutDataChartsItsReason() throws {
        var dataset = Data.lumen
        dataset.salesState = .needsVendorNumber
        let report = try #require(FunnelReport.make(dataset, days: 28))
        let chart = FunnelChart.make(dataset, report: report, stage: .trials, changes: [])
        #expect(chart.isEmpty)
        #expect(chart.gap == .needsVendorNumber)
        #expect(chart.gap?.chartText == "This step needs your vendor number.")
    }

    @Test func impressionsChartAsCounts() throws {
        let report = try #require(FunnelReport.make(Data.lumen, days: 28))
        let chart = FunnelChart.make(Data.lumen, report: report, stage: .impressions, changes: [])
        #expect(chart.isCount)
        #expect(chart.points.last?.value == 184_200)
        #expect(chart.minimum == 0)
        #expect(chart.average == nil)
    }
}
