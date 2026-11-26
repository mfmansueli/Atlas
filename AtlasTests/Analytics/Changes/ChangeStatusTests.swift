//
//  ChangeStatusTests.swift
//  AtlasTests
//

#if DEBUG
import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Board 92's After Changes: where each push stands (better, waiting for
/// data, too few to tell, a price change in Pricing → Results), the chart
/// of its step, and the layout at 860 pt.
@MainActor
@Suite("Analytics · After Changes states")
struct ChangeStatusTests {
    private typealias Data = AnalyticsTestData
    private typealias AppIDs = DebugFixtures.AppID

    private var dataset: AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID,
            appName: "Lumen Journal",
            engagement: [
                Data.fact(back: 0, impressions: 106_100, views: 2440, downloads: 800),
                Data.fact(back: 30, impressions: 103_200, views: 1960, downloads: 640),
                Data.fact(back: 0, source: "App Referrer", impressions: 9000, views: 4000, downloads: 100),
                Data.fact(back: 80, impressions: 1),
            ]
        )
    }

    private func subtitle(back: Int) -> MeasuredChange {
        MeasuredChange(id: "s", date: Data.through.adding(-back).date, kind: .searchText, title: "New subtitle", localeCodes: ["en-US"])
    }

    @Test func aFinishedChangeThatHelpedIsBetter() throws {
        let change = subtitle(back: 27)
        let result = try #require(ChangeResult.make(change, dataset: dataset, context: .empty))
        let status = ChangeStatus.make(change, result: result)
        #expect(status == .better)
        #expect(status.title == "Better")
        #expect(status.pillStyle == .neutral)
        #expect(status.hasNumbers)
    }

    @Test func anEarlyReadIsWaitingForData() throws {
        let change = subtitle(back: 19)
        let result = try #require(ChangeResult.make(change, dataset: dataset, context: .empty))
        let status = ChangeStatus.make(change, result: result)
        #expect(status == .waiting(day: 20))
        #expect(status.title == "Day 20 of 28")
        #expect(status.pillStyle == .outline)
    }

    @Test func tooLittleTrafficIsTooFewToTell() {
        var dataset = dataset
        dataset.engagement = [
            Data.fact(back: 0, impressions: 90, views: 4), Data.fact(back: 30, impressions: 80, views: 3), Data.fact(back: 80, impressions: 1),
        ]
        let change = subtitle(back: 27)
        let status = ChangeStatus.make(change, result: ChangeResult.make(change, dataset: dataset, context: .empty))
        #expect(status == .tooFew)
        #expect(status.title == "Too few to tell")
    }

    @Test func aPriceChangeLeadsToPricingResults() {
        let prices = MeasuredChange(id: "p", date: Data.through.adding(-27).date, kind: .prices, title: "Prices", localeCodes: [])
        let status = ChangeStatus.make(prices, result: nil)
        #expect(status == .pricing)
        #expect(status.title == "In Pricing → Results")
        #expect(!status.hasNumbers)
        #expect(FindingAction.pricingResults.area == .pricing)
        #expect(FindingAction.pricingResults.section == .subscriptionPricing)
    }

    @Test func withoutDataOrABeforeItSaysSo() {
        #expect(ChangeStatus.make(subtitle(back: 27), result: nil) == .noData)
        var dataset = dataset
        dataset.engagement = [Data.fact(back: 0, impressions: 5000, views: 200), Data.fact(back: 10, impressions: 5000, views: 200)]
        let change = subtitle(back: 60)
        #expect(ChangeStatus.make(change, result: ChangeResult.make(change, dataset: dataset, context: .empty)) == .noBefore)
    }

    @Test func worseIsAmber() {
        #expect(ChangeStatus.worse.pillStyle == .warning)
        #expect(ChangeStatus.same.title == "About the same")
    }

    // MARK: - The chart and the layout

    @Test func theChartDrawsTheMeasuredStepDayByDay() throws {
        let change = subtitle(back: 27)
        let result = try #require(ChangeResult.make(change, dataset: dataset, context: .empty))
        let chart = try #require(ChangeChart.make(result, dataset: dataset, context: .empty))
        #expect(chart.stage == .pageViews)
        #expect(chart.points.count == result.before.length + result.after.length)
        #expect(chart.afterStart == result.before.length)
        #expect(chart.changeDay == change.day)
        // Search only, as the result counts it: the referrer's views stay out.
        let last = try #require(chart.points.last { $0.value != nil }?.value)
        #expect(abs(last - 2440.0 / 106_100) < 0.000_001)
        #expect(chart.points.compactMap(\.value).count == 2)
        #expect(chart.maximum > chart.minimum)
    }

    @Test func at860TheThreeResultsStackUnderA200PointChart() {
        #expect(Metrics.changeChartHeight == 200)
        #expect(ChangeResultLayout.chartHeight == 200)
        // 860 pt less the sidebar or the list of pushes leaves well under 640.
        #expect(ChangeResultLayout.stacksResults(width: 564))
        #expect(ChangeResultLayout.stacksResults(width: 639))
        #expect(!ChangeResultLayout.stacksResults(width: 640))
        #expect(!ChangeResultLayout.stacksResults(width: 900))
    }

    @Test func lumensPushesEachHaveAState() throws {
        let model = AnalyticsViewModel(app: DebugFixtures.lumen, store: DebugAnalyticsData.store(), services: DebugAnalyticsServices())
        model.configure(sellsSubscriptions: true, changes: ChangeLog.changes(for: AppIDs.lumen, in: DebugAnalyticsData.pushRecords))
        model.setContext(DebugAnalyticsData.context)
        let prices = try #require(model.changes.first { $0.kind == .prices })
        #expect(ChangeStatus.make(prices, result: model.results[prices.id]) == .pricing)
        let screenshots = try #require(model.changes.first { $0.kind == .screenshots })
        guard case .waiting = ChangeStatus.make(screenshots, result: model.results[screenshots.id]) else {
            Issue.record("The Oct 21 screenshots are still in their 28 days")
            return
        }
        for change in model.changes where change.kind != .prices {
            #expect(ChangeStatus.make(change, result: model.results[change.id]) != .noData, "\(change.title)")
        }
    }
}
#endif
