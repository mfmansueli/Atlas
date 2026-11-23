//
//  ArrivalsBreakdownTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Source Info and Campaign, from Apple's Detailed reports: read, kept, and
/// split by in Break It Down and per product page.
@Suite("Analytics · referrers and campaigns")
struct ArrivalsBreakdownTests {
    private typealias Data = AnalyticsTestData

    private static func detailed(
        page: String, source: String = "Web Referrer", referrer: String? = nil, campaign: String? = nil, views: Int, downloads: Int
    ) -> EngagementFact {
        var fact = Data.fact(territory: "", source: source, impressions: 0, views: views, downloads: downloads)
        fact.device = ""
        fact.page = page
        fact.referrer = referrer
        fact.campaign = campaign
        return fact
    }

    private var dataset: AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID, appName: "Lumen Journal",
            engagement: [Data.fact(territory: "US", impressions: 1000, views: 300, downloads: 90)],
            pages: [
                Self.detailed(page: "Prompts", referrer: "instagram.com", campaign: "spring_ig", views: 120, downloads: 40),
                Self.detailed(page: "Prompts", referrer: "reddit.com", views: 30, downloads: 6),
                Self.detailed(page: "Prompts", source: "App Referrer", referrer: "Notion", campaign: "notion_tpl", views: 50, downloads: 20),
                Self.detailed(page: "Default product page", source: "App Store Search", views: 100, downloads: 24),
            ],
            events: [], subscribers: []
        )
    }

    private var period: AnalyticsPeriod { AnalyticsPeriod(ending: Data.through, length: 28) }
    private var context: AnalyticsContext { AnalyticsContext(primaryLocale: StoreLocaleCatalog.locale(code: "en-US")) }

    @Test func detailedReportsNameTheReferrerAndCampaign() {
        let table = DelimitedTable(text: """
        Date,App Apple Identifier,Download Type,Page Title,Source Type,Source Info,Campaign,Device,Territory,Counts
        2026-11-09,1,First-time download,Prompts,Web referrer,instagram.com,spring_ig,iPhone,US,12
        2026-11-09,1,First-time download,Prompts,App Store search,null,,iPhone,US,5
        """)
        let facts = EngagementReportParser.downloads(table, appID: "1")
        #expect(facts.compactMap(\.referrer) == ["instagram.com"])
        #expect(facts.compactMap(\.campaign) == ["spring_ig"])
        #expect(facts.first { $0.referrer == nil }?.downloads == 5)
    }

    /// The Standard reports have neither column.
    @Test func standardReportsHaveNoReferrer() {
        let table = DelimitedTable(text: """
        Date,App Apple Identifier,Download Type,Source Type,Device,Territory,Counts
        2026-11-09,1,First-time download,Web referrer,iPhone,US,12
        """)
        let facts = EngagementReportParser.downloads(table, appID: "1")
        #expect(facts.allSatisfy { $0.referrer == nil && $0.campaign == nil })
    }

    @Test func referrersAndCampaignsSplitTheDetailedNumbers() {
        let referrers = BreakdownTable.make(dataset, dimension: .referrer, period: period, context: context)
        #expect(Set(referrers.rows.map(\.id)) == ["instagram.com", "reddit.com", "Notion"])
        #expect(referrers.rows.first { $0.id == "Notion" }?.detail == "Links from other apps")
        #expect(referrers.rows.first { $0.id == "instagram.com" }?.totals.downloads == 40)
        #expect(!BreakdownDimension.referrer.hasSales)

        let campaigns = BreakdownTable.make(dataset, dimension: .campaign, period: period, context: context)
        #expect(Set(campaigns.rows.map(\.id)) == ["spring_ig", "notion_tpl"])
        #expect(campaigns.rows.first { $0.id == "spring_ig" }?.detail == "Prompts")
    }

    @Test func aPageSaysWhereItsLinkIsUsed() throws {
        let made = try #require(ProductPageNumbers.make(from: dataset.pages))
        let prompts = try #require(made.byPage["Prompts"])
        #expect(prompts.arrivals.map(\.title) == ["Campaign “spring_ig”", "instagram.com", "Campaign “notion_tpl”", "Notion", "reddit.com"])
        #expect(ProductPageNumbersText.arrivals(prompts.arrivals) == "Most from Campaign “spring_ig” · 4 more")
        #expect(made.byPage["Default product page"]?.arrivals.isEmpty == true)
        #expect(ProductPageNumbersText.arrivals([]) == nil)
    }

    /// The archive keeps the Detailed rows' source, referrer and campaign,
    /// and an older archive without them still reads.
    @Test func theArchiveKeepsWhereTheyCameFrom() throws {
        var archive = EngagementArchive()
        var fact = Self.detailed(page: "Prompts", referrer: "instagram.com", campaign: "spring_ig", views: 3, downloads: 1)
        fact.territory = "US"
        archive.apply([EngagementBatch(
            instanceID: "i1", kind: .engagement, isDetailed: true, processing: Data.through, facts: [fact]
        )])
        let kept = try #require(archive.pageFacts.first)
        #expect(kept.territory.isEmpty)
        #expect(kept.source == "Web Referrer")
        #expect(kept.referrer == "instagram.com")
        #expect(kept.campaign == "spring_ig")

        let old = Foundation.Data(#"{"d":20250,"t":"","s":"","v":"","p":"Prompts","i":1,"w":2,"n":1,"r":0}"#.utf8)
        let decoded = try JSONDecoder().decode(EngagementFact.self, from: old)
        #expect(decoded.referrer == nil && decoded.campaign == nil)
    }

    /// Alba's 526 impressions left no referrer or campaign above Apple's
    /// five-person floor: the table says why instead of staying blank.
    @Test func anEmptySplitSaysWhy() {
        for dimension in BreakdownDimension.allCases {
            #expect(dimension.emptyText.contains("five"), "\(dimension)")
        }
        #expect(BreakdownDimension.campaign.emptyText.contains("App Analytics → Campaigns"))
    }
}
