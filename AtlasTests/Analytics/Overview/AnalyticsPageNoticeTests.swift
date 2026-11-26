//
//  AnalyticsPageNoticeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the notice above the page")
struct AnalyticsPageNoticeTests {
    private let ready = AnalyticsAvailability.ready(since: nil, days: 90)

    private func choose(_ availability: AnalyticsAvailability, activity: AnalyticsActivity = .idle, preparing: Int = 0) -> AnalyticsPageNotice? {
        AnalyticsPageNotice.choose(AnalyticsPageNotice.Inputs(availability: availability, activity: activity, appName: "Lumen", preparingReports: preparing))
    }

    @Test func eachMissingPartHasItsNoticeAndAction() {
        #expect(choose(.missingVendorNumber) == .missingVendorNumber)
        #expect(AnalyticsPageNotice.missingVendorNumber.action == .addVendorNumber)
        #expect(choose(.noSalesAccess)?.action == .fixSalesRole)
        #expect(choose(.partial(.sales)) == .partial(.sales))
        #expect(choose(.partial(.engagement))?.bannerKind == .info)
        #expect(choose(.stale(days: 5))?.action == .checkAgain)
        #expect(choose(.stale(days: 5))?.identifier == "analytics.stale")
    }

    @Test func oneAtATimeAFailedCheckFirst() {
        #expect(choose(.missingVendorNumber, activity: .failed("Analytics didn’t load.")) == .failed("Analytics didn’t load."))
        #expect(choose(.partial(.sales), preparing: 2) == .partial(.sales))
        #expect(choose(ready, preparing: 2) == .preparingReports(count: 2, asked: nil))
        #expect(choose(ready) == nil)
    }

    @Test func theSetupStatesTakeThePageInstead() {
        #expect(choose(.notSetUp, activity: .failed("x")) == nil)
        #expect(choose(.waitingForApple(asked: nil)) == nil)
        #expect(choose(.downloading(finished: 0)) == nil)
    }

    @Test func theStaleNoticeSaysHowFarBehind() {
        let notice = AnalyticsPageNotice.stale(days: 5, newest: nil, lastChecked: nil)
        #expect(notice.title(appName: "Lumen") == "5 days behind (usually 1 to 2).")
        #expect(notice.message(now: .now) == nil)
        #expect(AnalyticsPageNotice.preparingReports(count: 1, asked: nil).title(appName: "Lumen") == "Apple is preparing 1 more report for Lumen.")
        #expect(AnalyticsNoticeAction.checkAgain.title == "Check Again")
    }
}
