//
//  ReviewShotsUITests.swift
//  AtlasUITests
//

import XCTest

/// Review screenshots made for the person on Pricing's cards (README —
/// Pricing: review screenshots), in the `rs-*` DEBUG scenes: Use This
/// Capture, Accept All of what Claude Code made, Show Larger, and the
/// banner of a run that couldn't find the paywall. Nothing leaves the Mac.
@MainActor
final class ReviewShotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testUseThisCaptureWaitsInReviewAndPushAndCanBeUndone() {
        app.launch(debugScene: "rs-match")
        let use = app.buttons["pricing.card.reviewShots.useCapture"].firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["pricing.card.reviewShots.useForAll"].firstMatch.exists, "Three products miss one")
        use.click()

        let undo = app.buttons["pricing.card.reviewShots.undo"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.card.reviewShots.accepted").exists)
        undo.click()
        XCTAssertTrue(app.buttons["pricing.card.reviewShots.useCapture"].firstMatch.waitForExistence(timeout: 5))
    }

    func testAcceptAllTakesEveryImageClaudeCodeMade() {
        app.launch(debugScene: "rs-arrived")
        let acceptAll = app.buttons["pricing.reviewShots.acceptAll"]
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pricing.card.reviewShots.suggested").exists)
        acceptAll.click()

        XCTAssertTrue(acceptAll.waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("pricing.card.reviewShots.suggested").exists)
        XCTAssertTrue(element("pricing.card.reviewShots.accepted").exists)
    }

    func testShowLargerShowsThemSideBySide() {
        app.launch(debugScene: "rs-preview")
        let preview = element("pricing.reviewShots.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["pricing.reviewShots.preview.acceptAll"].exists)
        app.buttons["pricing.reviewShots.preview.accept"].firstMatch.click()
        app.buttons["pricing.reviewShots.preview.close"].click()
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5))
    }

    func testARunThatCouldntFindThePaywallAsksWhereItIs() {
        app.launch(debugScene: "rs-fail-nav")
        let banner = element("pricing.reviewShots.notFound")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        let route = app.textFields["pricing.reviewShots.route"]
        XCTAssertTrue(route.exists)
        route.click()
        route.typeText("Settings → Lumen Plus")
        XCTAssertTrue(app.buttons["pricing.reviewShots.tryAgain"].exists)
        app.buttons["pricing.reviewShots.notNow"].click()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        // The manual path stays.
        XCTAssertTrue(app.buttons["pricing.card.reviewScreenshot"].firstMatch.exists)
    }

    func testNoPricesOffersAStoreKitConfiguration() {
        app.launch(debugScene: "rs-fail-price")
        XCTAssertTrue(element("pricing.reviewShots.noPrices").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["pricing.reviewShots.storeKit"].exists)
        app.buttons["pricing.reviewShots.notNow"].click()
        XCTAssertTrue(element("pricing.reviewShots.noPrices").waitForNonExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
