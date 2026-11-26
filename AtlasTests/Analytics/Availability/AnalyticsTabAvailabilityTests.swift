//
//  AnalyticsTabAvailabilityTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Each Analytics view's case: the empty state's title and the card's
/// summary (read by the strip and the Overview's KPIs) say the same thing,
/// and the views without Apple's rules stay available.
@Suite("Analytics · each view's case")
struct AnalyticsTabAvailabilityTests {
    private func dataset(days: Int, downloads: Int) -> AnalyticsDataset {
        var engagement = (0..<days).map { AnalyticsTestData.fact(back: $0, impressions: 50, views: 4) }
        if !engagement.isEmpty { engagement[0].downloads = downloads }
        return AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Parcel Pal", engagement: engagement)
    }

    @Test func applesMinimumIsFivePeople() {
        #expect(AnalyticsTabAvailability.minimumPeople == 5)
    }

    @Test func eachCaseHasATitleAndTheSameCaseOnItsCard() {
        let cases: [(AnalyticsTabAvailability, String, String)] = [
            (.noSubscriptionsSold, "No subscriptions sold yet", "None sold yet"),
            (.noPaidSubscribers(trials: 1), "No paid subscribers yet", "No paid subscribers yet"),
            (.tooFewSubscribers(count: 4), "Too few subscribers to show rates", "Too few to show rates"),
            (.versionTooNew(version: "1.4", previous: "1.3", previousRate: 2.1), "1.4 is too new to tell", "1.4 too new to tell"),
            (.notEnoughPeople, "Not enough people yet", "Not enough people yet"),
            (.noCrashes, "No crashes reported", "No crashes reported"),
        ]
        for (state, title, summary) in cases {
            #expect(state.title == title)
            #expect(state.cardSummary == summary)
            #expect(!state.isAvailable)
            #expect(state.title.split(separator: " ").count <= 8, "Titles are at most 8 words")
        }
    }

    @Test func availableSaysNothing() {
        #expect(AnalyticsTabAvailability.available.isAvailable)
        #expect(AnalyticsTabAvailability.available.title.isEmpty)
        #expect(AnalyticsTabAvailability.available.cardSummary.isEmpty)
    }

    @Test func viewsWithoutApplesRulesStayAvailable() {
        let empty = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Parcel Pal")
        for tab in [AnalyticsTab.overview, .whatToTry, .afterChanges] {
            #expect(AnalyticsTabAvailability.make(tab, dataset: empty, now: .now) == .available)
            #expect(AnalyticsTabAvailability.make(tab, dataset: dataset(days: 3, downloads: 1), now: .now) == .available)
        }
    }

    @Test func aNewAppWithFourDownloadsHasNoRowsToBreakDown() {
        #expect(AnalyticsTabAvailability.make(.breakDown, dataset: dataset(days: 9, downloads: 4), now: .now) == .notEnoughPeople)
        #expect(AnalyticsTabAvailability.make(.breakDown, dataset: dataset(days: 9, downloads: 5), now: .now) == .available)
    }

    @Test func anEstablishedAppAlwaysBreaksDown() {
        #expect(AnalyticsTabAvailability.make(.breakDown, dataset: dataset(days: AnalyticsAvailability.newAppDays, downloads: 0), now: .now) == .available)
        #expect(AnalyticsTabAvailability.make(.breakDown, dataset: dataset(days: 0, downloads: 0), now: .now) == .available)
    }

    @Test func subscriptionsAndStabilityUseApplesRules() {
        let empty = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Parcel Pal")
        #expect(AnalyticsTabAvailability.make(.subscriptions, dataset: empty, now: .now) == .noSubscriptionsSold)
        #expect(AnalyticsTabAvailability.make(.stability, dataset: empty, now: .now) == .available)
        #expect(AnalyticsTabAvailability.make(.subscriptions, dataset: AnalyticsTestData.lumen, now: .now) == .available)
    }
}
