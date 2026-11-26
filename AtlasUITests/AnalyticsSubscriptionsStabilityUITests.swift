//
//  AnalyticsSubscriptionsStabilityUITests.swift
//  AtlasUITests
//

import XCTest

/// Subscriptions' two levels (the summary, then Retention, Offers or
/// Billing and Plans under "‹ Subscriptions"), Stability's Open Version,
/// and the empty states Apple's rules make (board 92), in their DEBUG
/// scenes. Nothing reaches Apple.
@MainActor
final class AnalyticsSubscriptionsStabilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Subscriptions

    func testRetentionOpensFromTheSummaryAndComesBack() {
        app.launch(debugScene: "an-sub")
        XCTAssertTrue(element("analytics.subscriptions").waitForExistence(timeout: 15))
        XCTAssertFalse(element("analytics.subscriptions.back").exists, "The summary is the first level")
        element("analytics.subscriptions.seeRetention").click()
        XCTAssertTrue(element("analytics.retention").waitForExistence(timeout: 10))
        XCTAssertTrue(element("analytics.subscriptions.breadcrumb").exists)
        element("analytics.subscriptions.back").click()
        XCTAssertTrue(element("analytics.subscriptions").waitForExistence(timeout: 10), "Back on the summary")
        XCTAssertFalse(element("analytics.retention").exists)
    }

    func testOffersOpenFromTheSummary() {
        app.launch(debugScene: "an-sub")
        XCTAssertTrue(element("analytics.subscriptions.seeOffers").waitForExistence(timeout: 15))
        element("analytics.subscriptions.seeOffers").click()
        XCTAssertTrue(element("analytics.offers").waitForExistence(timeout: 10))
        // ⌘[ is the back link's shortcut, but typeKey can't type "[" on a
        // layout without its own key for it (Italian, German…): click it.
        element("analytics.subscriptions.back").click()
        XCTAssertTrue(element("analytics.subscriptions").waitForExistence(timeout: 10), "Back on the summary")
    }

    func testBillingOpensFromItsNotice() {
        app.launch(debugScene: "an-sub")
        let notice = element("analytics.subscriptions.billingNotice")
        XCTAssertTrue(notice.waitForExistence(timeout: 15))
        app.buttons["See Billing and Plans"].firstMatch.click()
        XCTAssertTrue(element("analytics.billing").waitForExistence(timeout: 10))
        XCTAssertTrue(element("analytics.subscriptions.back").exists)
    }

    func testNothingSoldSaysWhenReportsStart() {
        app.launch(debugScene: "an-sub-none")
        let empty = element("analytics.subscriptions.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("No subscriptions sold yet"))
        XCTAssertTrue(hasText("Reports start"))
        XCTAssertTrue(text(of: element("analytics.tab.subscriptions")).contains("None sold yet") || hasText("None sold yet"), "The card says the same case")
        element("analytics.subscriptions.empty.action").click()
        XCTAssertTrue(element("analytics.origin").waitForExistence(timeout: 10), "Open Pricing goes to Pricing under From Analytics")
    }

    func testATrialWithoutAPaymentSaysNobodyPaidYet() {
        app.launch(debugScene: "an-sub-trial")
        XCTAssertTrue(element("analytics.subscriptions.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("No paid subscribers yet"))
    }

    func testTooFewSubscribersKeepTheCounts() {
        app.launch(debugScene: "an-sub-few")
        XCTAssertTrue(element("analytics.subscriptions.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("Too few subscribers to show rates"))
        XCTAssertTrue(element("analytics.empty.facts").exists)
        XCTAssertFalse(element("analytics.subscriptions.empty.action").exists)
    }

    // MARK: - Stability

    func testAVersionTooNewOpensTheVersion() {
        app.launch(debugScene: "an-crash-wait")
        XCTAssertTrue(element("analytics.stability.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("1.4 is too new to tell"))
        let open = element("analytics.stability.empty.action")
        XCTAssertTrue(open.exists)
        open.click()
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10), "The version's card is on the Overview")
    }

    func testANewAppHasNotEnoughPeople() {
        app.launch(debugScene: "an-crash-new")
        XCTAssertTrue(element("analytics.stability.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("Not enough people yet"))
    }

    func testNoCrashesReportedSaysWhy() {
        app.launch(debugScene: "an-crash-none")
        XCTAssertTrue(element("analytics.stability.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(hasText("No crashes reported"))
        XCTAssertFalse(element("analytics.stability.empty.action").exists)
    }

    // MARK: - Helpers

    private func hasText(_ string: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", string, string)
        return app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: 5)
    }

    /// A static text's string is its value on macOS; a button's is its label.
    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
