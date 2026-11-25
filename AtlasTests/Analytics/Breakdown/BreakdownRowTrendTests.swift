//
//  BreakdownRowTrendTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · a row's 90-day line")
struct BreakdownRowTrendTests {
    private typealias Data = AnalyticsTestData

    /// 100 days of Germany at 5% and the U.S. at 10%.
    private static var dataset: AnalyticsDataset {
        let facts = (0..<100).flatMap { back in
            [
                Data.fact(back: back, territory: "DE", impressions: 100, views: 5, downloads: 1),
                Data.fact(back: back, territory: "US", device: "iPad", impressions: 100, views: 10, downloads: 2),
            ]
        }
        return AnalyticsDataset(appID: Data.appID, appName: "Lumen Journal", engagement: facts)
    }

    private static func row(_ id: String) -> BreakdownRow {
        BreakdownRow(id: id, name: id, totals: FunnelTotals(), viewRate: .missing, downloadRate: .missing, startRate: .missing)
    }

    @Test func aTerritorysLineIsItsOwnRateAgainstTheWholeApp() throws {
        let filter = try #require(BreakdownRowTrend.filter(for: Self.row("DE"), dimension: .territory, context: .empty))
        let trend = try #require(BreakdownRowTrend.make(Self.dataset, filter: filter))
        #expect(trend.points.count == BreakdownRowTrend.days)
        #expect(trend.points.last?.day == Data.through)
        #expect(trend.points.allSatisfy { abs(($0.rate ?? 0) - 0.05) < 0.0001 })
        #expect(abs((trend.average ?? 0) - 0.075) < 0.0001)
    }

    @Test func aDeviceRowFiltersByDevice() throws {
        let filter = try #require(BreakdownRowTrend.filter(for: Self.row("iPad"), dimension: .device, context: .empty))
        let trend = try #require(BreakdownRowTrend.make(Self.dataset, filter: filter))
        #expect(abs((trend.points.last?.rate ?? 0) - 0.10) < 0.0001)
    }

    @Test func tooFewImpressionsLeaveDaysOutAndTooFewDaysDrawNothing() {
        let few = AnalyticsDataset(
            appID: Data.appID, appName: "Quiet Timer",
            engagement: (0..<10).map { Data.fact(back: $0, territory: "DE", impressions: 3, views: 1) }
        )
        #expect(BreakdownRowTrend.make(few, filter: FactFilter(territories: ["DE"])) == nil)
    }

    @Test func pagesReferrersAndCampaignsHaveNoLine() {
        for dimension in [BreakdownDimension.productPage, .referrer, .campaign] {
            #expect(BreakdownRowTrend.filter(for: Self.row("Prompts"), dimension: dimension, context: .empty) == nil)
        }
    }
}
