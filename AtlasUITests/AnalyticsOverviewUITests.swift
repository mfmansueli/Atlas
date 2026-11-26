//
//  AnalyticsOverviewUITests.swift
//  AtlasUITests
//

import XCTest

/// Analytics' structure and Overview (README-DS §16, board 92) in their
/// DEBUG scenes (canned reports; nothing reaches Apple): from Ask Apple for
/// Reports through waiting to the Overview, the four numbers and where
/// they lead, the funnel cards, Last push, and the Autopilot bar before
/// the first reports.
@MainActor
final class AnalyticsOverviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAskingThenWaitingThenTheOverview() {
        app.launch(debugScene: "an-flow")
        XCTAssertTrue(element("analytics.setup.off").waitForExistence(timeout: 15))
        XCTAssertFalse(element("analytics.tab").exists, "No strip before there is data")
        element("analytics.askButton").click()

        XCTAssertTrue(element("analytics.setup.waiting").waitForExistence(timeout: 10))
        XCTAssertFalse(element("analytics.tab").exists)
        element("analytics.setup.checkNow").click()

        // The store-page reports arrived; sales are still on their way.
        XCTAssertTrue(element("analytics.overview").waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.tab").exists)
        XCTAssertTrue(element("analytics.notice.partial.sales").exists, "One notice says what's still coming")
        XCTAssertTrue(element("analytics.kpis").exists)
        XCTAssertTrue(element("analytics.kpi.rating").exists)
        XCTAssertTrue(element("analytics.funnel.step.pageViews").exists)

        element("analytics.tab.breakDown").click()
        XCTAssertTrue(element("analytics.tab.breakDown").isSelected)
        XCTAssertFalse(element("analytics.overview").exists)
    }

    func testTheNumbersLeadToTheirViews() {
        app.launch(debugScene: "an-funnel")
        XCTAssertTrue(element("analytics.kpis").waitForExistence(timeout: 15))
        for kind in ["rating", "proceeds", "subscribers", "crashes"] {
            XCTAssertTrue(element("analytics.kpi.\(kind)").exists, "\(kind) is one of the four numbers")
        }
        XCTAssertFalse(element("analytics.kpi.downloads").exists, "Downloads are in the funnel already")

        element("analytics.kpi.subscribers").click()
        XCTAssertTrue(element("analytics.tab.subscriptions").isSelected)

        element("analytics.tab.overview").click()
        XCTAssertTrue(element("analytics.kpi.crashes").waitForExistence(timeout: 5))
        element("analytics.kpi.crashes").click()
        XCTAssertTrue(element("analytics.tab.stability").isSelected)

        element("analytics.tab.overview").click()
        XCTAssertTrue(element("analytics.kpi.proceeds").waitForExistence(timeout: 5))
        element("analytics.kpi.proceeds").click()
        XCTAssertTrue(element("analytics.tab.breakDown").isSelected)

        element("analytics.tab.overview").click()
        XCTAssertTrue(element("analytics.kpi.rating").waitForExistence(timeout: 5))
        element("analytics.kpi.rating").click()
        XCTAssertTrue(element("workspace.reviews").waitForExistence(timeout: 10), "Rating opens Ratings & Reviews")
    }

    func testTheStripSaysWhatEachViewHolds() {
        app.launch(debugScene: "an-funnel")
        let overview = element("analytics.tab.overview")
        XCTAssertTrue(overview.waitForExistence(timeout: 15))
        XCTAssertTrue(overview.isSelected)
        XCTAssertTrue(overview.label.contains("Fewer page views"), overview.label)
        XCTAssertTrue(element("analytics.tab.breakDown").label.contains("Country, language, source"))
        XCTAssertTrue(element("analytics.tab.afterChanges").label.contains("pushes"))
    }

    func testTheFunnelCardsAndTheLastPush() {
        app.launch(debugScene: "an-funnel")
        XCTAssertTrue(element("analytics.funnel.strip").waitForExistence(timeout: 15))
        let views = element("analytics.funnel.step.pageViews")
        XCTAssertTrue(views.label.contains("of impressions opened the page"), views.label)
        XCTAssertTrue(views.label.contains("Worse"), views.label)
        element("analytics.funnel.step.downloads").click()
        XCTAssertTrue(element("analytics.funnel.step.downloads").isSelected)

        let last = element("analytics.overview.lastPush")
        if !last.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -1200) }
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        element("analytics.overview.allChanges").click()
        XCTAssertTrue(element("analytics.tab.afterChanges").isSelected)
    }

    func testBeforeTheFirstReportsTheAutopilotBarOnlyAsks() {
        app.launch(debugScene: "an-waiting")
        XCTAssertTrue(element("analytics.setup.waiting").waitForExistence(timeout: 15))
        let actions = app.buttons.matching(identifier: "autopilotBar.action")
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.firstMatch.label, "Ask What Analytics Shows…")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
