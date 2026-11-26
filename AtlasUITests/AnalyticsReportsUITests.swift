//
//  AnalyticsReportsUITests.swift
//  AtlasUITests
//

import XCTest

/// Apple's newer reports in Analytics' DEBUG scenes (boards 59–62):
/// Retention, Offers, Billing, Stability, Reports from Apple and the
/// Overview's crash alert. Nothing reaches Apple.
@MainActor
final class AnalyticsReportsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testRetentionShowsTheSaveRateAndEachMessage() {
        app.launch(debugScene: "an-sub-ret")
        XCTAssertTrue(element("analytics.retention").waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.retention.saveRate").exists)
        XCTAssertTrue(element("analytics.retention.message.rm-before-you-go").exists)
        XCTAssertTrue(element("analytics.retention.message.none").exists, "No Message is the reference row")
    }

    func testRetentionWithoutRowsSaysWhy() {
        app.launch(debugScene: "an-sub-ret-none")
        XCTAssertTrue(element("analytics.retention.empty").waitForExistence(timeout: 15))
    }

    func testOffersListEachOffer() {
        app.launch(debugScene: "an-sub-offers")
        XCTAssertTrue(element("analytics.offers").waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.offers.row.PODCAST30").exists)
    }

    func testTurningOnTheGracePeriodAsksFirst() {
        app.launch(debugScene: "an-sub-billing")
        XCTAssertTrue(element("analytics.billing").waitForExistence(timeout: 15))
        // The notice's button asks first; analytics.billing.turnOn is the
        // confirmation's own Turn On.
        app.buttons["Turn On Billing Grace Period…"].firstMatch.click()
        XCTAssertTrue(element("analytics.billing.duration").waitForExistence(timeout: 5), "Picks the length before anything changes")
        app.typeKey(.escape, modifierFlags: [])
    }

    func testStabilityComparesTheNewestVersion() {
        app.launch(debugScene: "an-stab")
        XCTAssertTrue(element("analytics.stability").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "1.4", "1.4")).firstMatch.exists)
    }

    func testReportsFromAppleListsEveryReport() {
        app.launch(debugScene: "an-reports")
        XCTAssertTrue(element("analytics.reports").waitForExistence(timeout: 15))
        for kind in ["retention", "subscriptionEvents", "crashes", "installs", "sessions", "webPreview", "widgets"] {
            XCTAssertTrue(element("analytics.reports.row.\(kind)").exists, "\(kind) has a row")
        }
    }

    func testTheOverviewWarnsAboutACrashingVersion() {
        app.launch(debugScene: "an-overview")
        XCTAssertTrue(element("overview.stability").waitForExistence(timeout: 15))
        element("overview.stability.open").click()
        XCTAssertTrue(element("analytics.stability").waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
