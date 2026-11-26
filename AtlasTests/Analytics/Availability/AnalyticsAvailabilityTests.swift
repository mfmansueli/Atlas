//
//  AnalyticsAvailabilityTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · what the section can show")
struct AnalyticsAvailabilityTests {
    private let asked = Date(timeIntervalSince1970: 1_793_000_000)
    private let firstDay = Date(timeIntervalSince1970: 1_793_500_000)

    private func make(
        setup: AnalyticsSetup = .ready,
        activity: AnalyticsActivity = .idle,
        hasData: Bool = true,
        sells: Bool = true,
        sales: SalesState = .ready,
        engagement: EngagementState = .ready,
        stale: Int? = nil,
        days: Int = 90
    ) -> AnalyticsAvailability {
        AnalyticsAvailability.make(AnalyticsAvailability.Inputs(
            setup: setup, activity: activity, hasData: hasData, askedOn: asked, sellsSubscriptions: sells,
            salesState: sales, engagementState: engagement, staleDays: stale, firstDay: firstDay, dayCount: days
        ))
    }

    @Test func beforeAskingItIsNotSetUp() {
        let state = make(setup: .off, hasData: false)
        #expect(state == .notSetUp)
        #expect(state.isBlocking)
        #expect(!state.showsStrip)
        #expect(!state.showsFindingsBadge)
        #expect(state.offersOnlyAsk)
        #expect(state.toolbarText == "Not set up")
    }

    @Test func aKeyWithoutAdminNeedsAnAdminKey() {
        #expect(make(setup: .keyCannotAsk, hasData: false) == .needsAdminKey)
        #expect(make(setup: .keyCannotAsk, hasData: false).toolbarText == "Needs an Admin key")
    }

    @Test func askedItWaitsForAppleThenDownloads() {
        #expect(make(setup: .waiting(asked: asked), hasData: false) == .waitingForApple(asked: asked))
        #expect(make(setup: .waiting(asked: asked), activity: .loading(finished: 1), hasData: false) == .downloading(finished: 1))
        #expect(make(setup: .waiting(asked: asked), hasData: false).toolbarText == "Waiting for Apple’s first reports")
        #expect(make(setup: .waiting(asked: asked), activity: .loading(finished: 0), hasData: false).toolbarText == "Downloading Apple’s reports")
    }

    @Test func readyWithoutNumbersIsStillTheFirstDownload() {
        #expect(make(activity: .loading(finished: 0), hasData: false) == .downloading(finished: 0))
        #expect(make(hasData: false) == .waitingForApple(asked: asked))
    }

    @Test func noticesComeOneAtATimeInOrder() {
        #expect(make(sales: .needsVendorNumber, engagement: .waiting(asked: nil), stale: 4) == .missingVendorNumber)
        #expect(make(sales: .keyCannotRead, stale: 4) == .noSalesAccess)
        #expect(make(engagement: .waiting(asked: nil), stale: 4) == .partial(.engagement))
        #expect(make(sales: .waiting, stale: 4) == .partial(.sales))
        #expect(make(stale: 4) == .stale(days: 4))
        #expect(make(stale: 4).isNotice)
        #expect(!make(stale: 4).isBlocking)
    }

    @Test func anAppWithoutSubscriptionsHasNoSalesNotice() {
        #expect(make(sells: false, sales: .needsVendorNumber) == .ready(since: firstDay, days: 90))
        #expect(make(sells: false, sales: .waiting) == .ready(since: firstDay, days: 90))
    }

    @Test func aNewAppSaysSinceWhenAndHowManyDays() {
        let state = make(days: 9)
        #expect(state == .ready(since: firstDay, days: 9))
        #expect(state.isNewApp)
        #expect(state.toolbarText == "Since \(AnalyticsText.day(firstDay)) · 9 days of data")
        #expect(make(days: 90).toolbarText == nil)
        #expect(!make(days: 90).isNewApp)
    }
}
