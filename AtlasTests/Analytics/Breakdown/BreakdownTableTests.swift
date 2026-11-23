//
//  BreakdownTableTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · break it down")
struct BreakdownTableTests {
    private typealias Data = AnalyticsTestData

    private var dataset: AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID,
            appName: "Lumen Journal",
            engagement: [
                Data.fact(territory: "US", impressions: 61200, views: 3610, downloads: 1190),
                Data.fact(territory: "DE", impressions: 24800, views: 1480, downloads: 260),
                Data.fact(territory: "AT", impressions: 2000, views: 120, downloads: 21),
                Data.fact(territory: "TR", source: "Web Referrer", device: "iPad", impressions: 1100, views: 40, downloads: 1),
                Data.fact(back: 40, territory: "US", impressions: 5, views: 5, downloads: 5),
            ],
            pages: [
                { var fact = Data.fact(impressions: 900, views: 90, downloads: 30); fact.page = "Prompts"; return fact }(),
                { var fact = Data.fact(impressions: 9000, views: 500, downloads: 150); fact.page = "Default product page"; return fact }(),
            ],
            events: [
                Data.event(.trialStart, 172, territory: "US"), Data.event(.paidStart, 8, territory: "US", periods: 1),
                Data.event(.trialStart, 33, territory: "DE"),
            ],
            subscribers: [SubscriberFact(day: Data.through, appID: Data.appID, subscription: "Annual", territory: "DE", charges: 9, proceeds: 430)]
        )
    }

    private var context: AnalyticsContext {
        AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: ["en-US", "de-DE"].compactMap(StoreLocaleCatalog.locale(code:)),
            machineTranslated: ["de-DE"]
        )
    }

    private var period: AnalyticsPeriod { AnalyticsPeriod(ending: Data.through, length: 28) }

    @Test func territoriesAreComparedWithTheAppsAverage() throws {
        let table = BreakdownTable.make(dataset, dimension: .territory, period: period, context: context)
        #expect(table.rows.map(\.id) == ["US", "DE", "AT", "TR"])
        let germany = try #require(table.row("DE"))
        #expect(germany.name == "Germany")
        #expect(germany.detail == "German")
        #expect(germany.totals.downloads == 260)
        #expect(germany.downloadRate.measured?.standing == .worse)
        #expect(germany.totals.starts == 33)
        #expect(germany.totals.proceeds == 430)
        #expect(table.row("US")?.downloadRate.measured?.standing == .better)
        #expect(table.row("US")?.totals.starts == 180)
        // 1 of 40: counts, not a rate.
        #expect(table.row("TR")?.downloadRate == .tooFew(count: 1, total: 40))
        #expect(table.totals.impressions == 89100)
    }

    @Test func rowsSortByAnyColumnWithMissingValuesLast() {
        let table = BreakdownTable.make(dataset, dimension: .territory, period: period, context: context)
        #expect(table.sorted(by: .downloadRate, ascending: true).first?.id == "TR")
        #expect(table.sorted(by: .name, ascending: true).map(\.id) == ["AT", "DE", "TR", "US"])
        #expect(table.sorted(by: .proceeds, ascending: false).first?.id == "DE")
    }

    @Test func aLanguageAddsUpTheTerritoriesThatSeeItsPage() throws {
        let table = BreakdownTable.make(dataset, dimension: .language, period: period, context: context)
        let german = try #require(table.row("de-DE"))
        #expect(german.totals.impressions == 26800)
        #expect(german.detail == "2 territories")
        // Türkiye has no page of its own: it sees the primary one.
        #expect(table.row("en-US")?.totals.impressions == 62300)
        #expect(table.footer.contains("A language sums the territories"))
    }

    @Test func sourcesHaveNoSalesAndSayWhy() throws {
        let table = BreakdownTable.make(dataset, dimension: .source, period: period, context: context)
        let search = try #require(table.row("App Store Search"))
        #expect(search.totals.starts == nil)
        #expect(search.totals.proceeds == nil)
        #expect(search.startRate == .missing)
        #expect(search.detail != nil)
        #expect(table.footer.contains("doesn’t split starts and proceeds by source"))
        #expect(!BreakdownDimension.source.hasSales)
    }

    @Test func devicesAndProductPagesSplitToo() {
        let devices = BreakdownTable.make(dataset, dimension: .device, period: period, context: context)
        #expect(Set(devices.rows.map(\.id)) == ["iPhone", "iPad"])
        let pages = BreakdownTable.make(dataset, dimension: .productPage, period: period, context: context)
        #expect(pages.rows.map(\.id) == ["Default product page", "Prompts"])
        #expect(pages.row("Prompts")?.detail == "Custom product page")
        #expect(pages.row("Prompts")?.totals.downloads == 30)
    }

    // MARK: - Context

    @Test func aTerritorySeesItsLanguageElseThePrimaryPage() {
        #expect(context.locale(for: "DE")?.code == "de-DE")
        #expect(context.locale(for: "AT")?.code == "de-DE")
        #expect(context.locale(for: "TR")?.code == "en-US")
        #expect(context.textState(for: "DE") == .machineTranslated)
        #expect(context.textState(for: "TR") == .noPage)
        #expect(context.textState(for: "US") == .written)
        #expect(context.hasOwnScreenshots(for: "DE") == nil)
        #expect(AnalyticsContext.empty.textState(for: "DE") == nil)
        #expect(context.territories(showing: ["de-DE"], among: ["US", "DE", "AT", "TR"]) == ["DE", "AT"])
    }
}
