//
//  AnalyticsUITests.swift
//  AtlasUITests
//

import XCTest

/// Analytics (⌘9) in its DEBUG scenes (the sample account's canned
/// reports; nothing reaches Apple): turning it on, the funnel and its
/// chart, Break It Down with the inspector and the jump to the fix, What
/// to Try, After Changes, Subscriptions and the settings sheet.
@MainActor
final class AnalyticsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Setup

    func testAskingAppleMovesFromOffToWaiting() {
        app.launch(debugScene: "an-off")
        XCTAssertTrue(element("analytics.setup.off").waitForExistence(timeout: 15))
        XCTAssertFalse(element("analytics.tab.overview").exists, "No views before there are numbers")
        element("analytics.askButton").click()
        XCTAssertTrue(element("analytics.setup.waiting").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Waiting for Apple’s first reports"].exists)
    }

    func testAKeyThatIsntAdminSaysWhatIsNeeded() {
        app.launch(debugScene: "an-norole")
        XCTAssertTrue(element("analytics.setup.keyCannotAsk").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Only an Admin key can ask Apple for reports"].exists)
        XCTAssertTrue(app.buttons["Open Users and Access"].exists)
    }

    // MARK: - Funnel

    func testTheFunnelShowsEveryStepAndChartsTheRateClicked() {
        app.launch(debugScene: "an-funnel")
        XCTAssertTrue(element("analytics.funnel.strip").waitForExistence(timeout: 15))
        for stage in ["impressions", "pageViews", "downloads", "trials", "paid"] {
            XCTAssertTrue(element("analytics.funnel.step.\(stage)").exists, "\(stage) has a tile")
        }
        XCTAssertTrue(element("analytics.funnel.callout").exists)
        XCTAssertTrue(element("analytics.dataThrough").exists)
        XCTAssertTrue(element("analytics.funnel.chart").exists)
        XCTAssertFalse(element("analytics.stale").exists)

        element("analytics.funnel.step.trials").click()
        XCTAssertTrue(app.staticTexts["Trials per download, daily"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("analytics.funnel.step.trials").isSelected)
        // 90 days.
        element("analytics.period").radioButtons["90 days"].click()
        XCTAssertTrue(element("analytics.funnel.strip").waitForExistence(timeout: 5))
    }

    func testWithoutTheVendorNumberTheNoticeSaysWhatIsNeeded() {
        app.launch(debugScene: "an-novendor")
        XCTAssertTrue(element("analytics.funnel.strip").waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.notice.vendorNumber").exists, "One notice above the page")
        XCTAssertFalse(element("analytics.funnel.note").exists, "The note under the steps waits for sales")
        let fix = element("analytics.notice.addVendorNumber")
        XCTAssertTrue(fix.exists)
        fix.click()
        XCTAssertTrue(app.textFields["analytics.settings.vendorNumber"].waitForExistence(timeout: 5))
        element("analytics.settings.done").click()
        XCTAssertTrue(app.textFields["analytics.settings.vendorNumber"].waitForNonExistence(timeout: 5))
    }

    func testDataOlderThanUsualOffersToCheckAgain() {
        app.launch(debugScene: "an-stale")
        XCTAssertTrue(element("analytics.stale").waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.checkAgain").exists)
    }

    // MARK: - Break It Down

    func testARowOpensTheInspectorAndItsActionLeadsToTheFixAndBack() {
        app.launch(debugScene: "an-bd")
        XCTAssertTrue(element("analytics.breakdown.table").waitForExistence(timeout: 15))
        XCTAssertFalse(element("analytics.breakdown.inspector").exists)
        element("analytics.breakdown.row.DE").click()
        XCTAssertTrue(element("analytics.breakdown.inspector").waitForExistence(timeout: 5))
        let open = app.buttons["Open Store Page in German"]
        XCTAssertTrue(open.exists)
        // The inspector's actions are at its end, under the fold at 1200 × 780.
        // The inspector is an overlay, and accessibility hit-testing finds the
        // table under it, so XCUITest never calls its buttons hittable: scroll
        // and click at the button.
        let window = app.windows.firstMatch
        let corner = window.coordinate(withNormalizedOffset: .zero)
        func at(_ frame: CGRect) -> XCUICoordinate {
            corner.withOffset(CGVector(dx: frame.midX - window.frame.minX, dy: frame.midY - window.frame.minY))
        }
        at(element("analytics.breakdown.inspector").frame).scroll(byDeltaX: 0, deltaY: -600)
        at(open.frame).click()

        // The Store Page, saying where the person came from.
        XCTAssertTrue(element("analytics.origin").waitForExistence(timeout: 10))
        element("analytics.origin.back").click()
        XCTAssertTrue(element("analytics.breakdown.table").waitForExistence(timeout: 10), "Back on Break It Down")
        XCTAssertFalse(element("analytics.origin").exists)
    }

    func testTheBreakdownSwitchesDimensionAndSorts() {
        app.launch(debugScene: "an-bd")
        XCTAssertTrue(element("analytics.breakdown.row.US").waitForExistence(timeout: 15))
        // Source, in the segmented control (Country, Language, Source, Device, Product Page).
        element("analytics.breakdown.dimension").radioButtons["Source"].click()
        XCTAssertTrue(element("analytics.breakdown.row.App Store Search").waitForExistence(timeout: 5))
        XCTAssertFalse(element("analytics.breakdown.row.US").exists)
        element("analytics.breakdown.sort.viewRate").click()
        XCTAssertTrue(element("analytics.breakdown.footer").exists)
        // Referrer and Campaign, from the Detailed reports, in More.
        element("analytics.breakdown.more").click()
        app.menuItems["Referrer"].click()
        XCTAssertTrue(element("analytics.breakdown.row.instagram.com").waitForExistence(timeout: 5))
        element("analytics.breakdown.more").click()
        app.menuItems["Campaign"].click()
        XCTAssertTrue(element("analytics.breakdown.row.spring_ig").waitForExistence(timeout: 5))
    }

    // MARK: - What to Try

    func testAFindingCanBeDismissedAndRestored() {
        app.launch(debugScene: "an-find")
        let finding = element("analytics.finding.territory.downloads.DE")
        XCTAssertTrue(finding.waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.finding.assistant.search-tap-through").exists, "The assistant's finding comes first")
        finding.buttons["Dismiss"].firstMatch.click()
        XCTAssertTrue(finding.waitForNonExistence(timeout: 5))

        // Dismissed.
        element("analytics.findings.filter.2").click()
        let restore = element("analytics.findings.restore")
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.click()
        element("analytics.findings.filter.0").click()
        XCTAssertTrue(finding.waitForExistence(timeout: 5))
    }

    func testAnAppWithNineDaysHasNoFindingsYet() {
        app.launch(debugScene: "an-find-none")
        XCTAssertTrue(element("analytics.findings.none").waitForExistence(timeout: 15))
    }

    // MARK: - After Changes, Subscriptions, Settings

    func testAChangeShowsItsBeforeAndAfter() {
        app.launch(debugScene: "an-chg")
        XCTAssertTrue(element("analytics.changes.result").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Counts behind it"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "analytics.changes.row").count, 5)
    }

    func testSubscriptionsLeadToRetention() {
        app.launch(debugScene: "an-sub")
        XCTAssertTrue(element("analytics.subscriptions").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Active subscribers"].exists)
        let openRetention = element("analytics.subscriptions.openRetention")
        // Under the fold at 1200 × 780: scroll the summary up first.
        for _ in 0..<10 where !openRetention.isHittable {
            element("analytics.subscriptions").scroll(byDeltaX: 0, deltaY: -200)
        }
        openRetention.click()
        XCTAssertTrue(element("analytics.origin").waitForExistence(timeout: 10))
    }

    func testSettingsListTheAppsAndConfirmBeforeStopping() {
        app.launch(debugScene: "an-set")
        XCTAssertTrue(app.textFields["analytics.settings.vendorNumber"].waitForExistence(timeout: 15))
        let stop = element("analytics.settings.stop")
        XCTAssertTrue(stop.exists)
        XCTAssertFalse(element("analytics.settings.stop.confirm").exists)
        stop.click()
        XCTAssertTrue(element("analytics.settings.stop.confirm").waitForExistence(timeout: 5), "Says what happens before anything does")
    }

    func testTheOverviewHasAnAnalyticsRow() {
        app.launch(debugScene: "an-overview")
        XCTAssertTrue(element("overview.afterRelease.row.analytics").waitForExistence(timeout: 15))
        element("overview.afterRelease.open.analytics").click()
        XCTAssertTrue(element("analytics.funnel.strip").waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
