//
//  ChangeLogTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · after a change")
struct ChangeLogTests {
    private typealias Data = AnalyticsTestData

    private func change(_ id: String, section: AppWorkspaceSection, title: String, region: String = "US", old: String = "", new: String = "") -> PendingChange {
        PendingChange(id: id, appID: Data.appID, section: section, group: "", title: title, flagRegion: region, oldValue: old, newValue: new, requests: [])
    }

    private func record(_ changes: [PendingChange], screenshots: ScreenshotPushSummary? = nil, back: Int = 10) -> PushRecord {
        PushRecord(date: Data.through.adding(-back).date, appID: Data.appID, appName: "Lumen", title: "", pushed: changes, screenshots: screenshots)
    }

    // MARK: - Reading the push history

    @Test func aPushBecomesOneChangePerKind() {
        let pushed = record([
            change(
                "storePage.1.version.v.en-US.subtitle", section: .storePage, title: "English (U.S.) · Subtitle",
                old: "Mood journal", new: "Mood journal & prompts"
            ),
            change("storePage.1.version.v.de-DE.description", section: .storePage, title: "German · Description", region: "DE"),
            change("storePage.1.version.v.fr-FR.description", section: .storePage, title: "French · Description", region: "FR"),
            change("storePage.1.inApp.annual.en-US.name", section: .storePage, title: "English (U.S.) · Annual · Name"),
            change("pricing.annual.BR", section: .subscriptionPricing, title: "Brazil", region: "BR"),
            change("pricing.annual.IN", section: .subscriptionPricing, title: "India", region: "IN"),
            change("retention.message.1.m1", section: .subscriptionPricing, title: "Before you go"),
            change("info.category", section: .appInformation, title: "Category"),
        ])
        let changes = ChangeLog.changes(in: pushed)
        #expect(changes.map(\.kind) == [.searchText, .pageText, .prices, .inAppTexts])
        let search = changes[0]
        #expect(search.title == "New subtitle · English (U.S.)")
        #expect(search.localeCodes == ["en-US"])
        #expect(search.oldValue == "Mood journal")
        #expect(search.stage == .pageViews)
        #expect(search.stageTitle == "Tap-through from search")
        #expect(changes[1].title == "New description · 2 languages")
        #expect(changes[1].stage == .downloads)
        #expect(changes[2].title == "Prices · 2 countries")
        #expect(changes[2].stage == nil)
        #expect(changes[3].stage == .trials)
    }

    @Test func aScreenshotPushIsAChangeAndARestoreIsNot() {
        let summary = ScreenshotPushSummary(pushedCount: 10, failures: [], locales: ["en-US", "en-GB"], keptLocales: [], backupID: nil, isRestore: false)
        let changes = ChangeLog.changes(in: record([], screenshots: summary))
        #expect(changes.map(\.kind) == [.screenshots])
        #expect(changes.first?.title == "New screenshots · 2 languages")
        var restore = summary
        restore.isRestore = true
        #expect(ChangeLog.changes(in: record([], screenshots: restore)).isEmpty)
    }

    @Test func onlyTheAppsOwnPushesNewestFirst() {
        let first = record([change("storePage.1.version.v.en-US.keywords", section: .storePage, title: "English (U.S.) · Keywords")], back: 40)
        let second = record([change("storePage.1.version.v.en-US.name", section: .storePage, title: "English (U.S.) · Name")], back: 5)
        var other = second
        other.appID = "another"
        let changes = ChangeLog.changes(for: Data.appID, in: [first, other, second])
        #expect(changes.map(\.title) == ["New name · English (U.S.)", "New keywords · English (U.S.)"])
    }

    // MARK: - Results

    private var dataset: AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID,
            appName: "Lumen Journal",
            engagement: [
                // After: 2,440 of 106,100 from search; before: 1,960 of 103,200.
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

    @Test func aFinishedResultComparesTwentyEightDaysEitherSide() throws {
        let result = try #require(ChangeResult.make(subtitle(back: 27), dataset: dataset, context: .empty))
        #expect(result.state == .final)
        #expect(result.before.length == 28)
        #expect(result.after.length == 28)
        // Search only: the referrer's page views don't count.
        #expect(result.main.before.text == AnalyticsText.percent(1960.0 / 103_200))
        #expect(result.main.after.text == AnalyticsText.percent(2440.0 / 106_100))
        #expect(result.main.comparison.outcome == .higher(.sure))
        #expect(result.statusText == "Better · sure")
        #expect(result.beforeAfterText == "\(result.main.before.text) → \(result.main.after.text)")
        #expect(result.others.map(\.title) == ["Downloads per page view", "Trials per download"])
    }

    @Test func anEarlyReadSaysWhichDayItIs() throws {
        let result = try #require(ChangeResult.make(subtitle(back: 19), dataset: dataset, context: .empty))
        #expect(result.state == .measuring(day: 20, ends: Data.through.adding(8).date))
        #expect(result.statusText == "Day 20 of 28")
    }

    @Test func tooLittleTrafficIsTooFewToTell() throws {
        var dataset = dataset
        dataset.engagement = [
            Data.fact(back: 0, impressions: 1110, views: 52), Data.fact(back: 30, impressions: 1020, views: 41), Data.fact(back: 80, impressions: 1),
        ]
        let result = try #require(ChangeResult.make(subtitle(back: 27), dataset: dataset, context: .empty))
        #expect(result.main.comparison.outcome == .same)
        dataset.engagement = [
            Data.fact(back: 0, impressions: 90, views: 4), Data.fact(back: 30, impressions: 80, views: 3), Data.fact(back: 80, impressions: 1),
        ]
        let few = try #require(ChangeResult.make(subtitle(back: 27), dataset: dataset, context: .empty))
        #expect(few.isTooFew)
        #expect(few.statusText == "Too few to tell")
    }

    @Test func aChangeOlderThanTheDataHasNoBefore() throws {
        var dataset = dataset
        dataset.engagement = [Data.fact(back: 0, impressions: 5000, views: 200), Data.fact(back: 10, impressions: 5000, views: 200)]
        let result = try #require(ChangeResult.make(subtitle(back: 60), dataset: dataset, context: .empty))
        #expect(result.state == .noBefore)
    }

    @Test func pricesAreLeftToPricingResults() {
        let prices = MeasuredChange(id: "p", date: Data.through.adding(-27).date, kind: .prices, title: "Prices", localeCodes: [])
        #expect(ChangeResult.make(prices, dataset: dataset, context: .empty) == nil)
    }

    @Test func aChangeInOneLanguageIsMeasuredWhereThatPageShows() throws {
        var dataset = dataset
        dataset.engagement += [
            Data.fact(back: 0, territory: "DE", impressions: 50000, views: 100),
            Data.fact(back: 30, territory: "DE", impressions: 50000, views: 4000),
        ]
        let context = AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: ["en-US", "de-DE"].compactMap(StoreLocaleCatalog.locale(code:))
        )
        let result = try #require(ChangeResult.make(subtitle(back: 27), dataset: dataset, context: context))
        // Germany sees the German page, so its numbers stay out.
        #expect(result.main.after.measured?.count == 2440)
        #expect(result.main.after.measured?.total == 106_100)
    }
}
