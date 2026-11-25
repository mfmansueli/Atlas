//
//  AnalyticsRedesignUITests.swift
//  AtlasUITests
//

import XCTest

/// The redesign's Analytics states in their DEBUG scenes (canned reports;
/// nothing reaches Apple): Stability's banner, What to Try's counted
/// views, a device's screenshot languages in the inspector, the settings
/// sheet's vendor line and stop confirmation, and a finding's jump to
/// Pricing.
@MainActor
final class AnalyticsRedesignUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testStabilityBannerOpensTheVersion() {
        app.launch(debugScene: "an-crash")
        XCTAssertTrue(element("analytics.stability.alert").waitForExistence(timeout: 15))
        let open = element("analytics.stability.openVersion")
        XCTAssertTrue(open.exists)
        open.click()
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10), "The version's card is on the Overview")
    }

    func testWhatToTryCountsEachView() {
        app.launch(debugScene: "an-find")
        let open = element("analytics.findings.filter.0")
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: open).contains("·"), "Open · N")
        XCTAssertTrue(text(of: element("analytics.findings.filter.2")).contains("·"), "Dismissed · N")
    }

    func testADeviceSaysWhichLanguagesItsSetCovers() {
        app.launch(debugScene: "an-bd-dev-ipad")
        let inspector = element("analytics.breakdown.inspector")
        XCTAssertTrue(inspector.waitForExistence(timeout: 15))
        let coverage = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "iPhone set", "iPhone set")
        XCTAssertTrue(inspector.staticTexts.matching(coverage).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open iPad 13″ Screenshots"].exists)
    }

    func testBrowseSaysWhatPeopleSee() {
        app.launch(debugScene: "an-bd-src-browse")
        let inspector = element("analytics.breakdown.inspector")
        XCTAssertTrue(inspector.waitForExistence(timeout: 15))
        let seen = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "App Preview", "App Preview")
        XCTAssertTrue(inspector.staticTexts.matching(seen).firstMatch.exists)
    }

    func testSettingsOpenOnTheStopConfirmation() {
        app.launch(debugScene: "an-set-stop")
        XCTAssertTrue(element("analytics.settings.stop.confirm").waitForExistence(timeout: 15))
    }

    func testWithoutAVendorNumberSettingsSaysStorePageNumbersStillWork() {
        app.launch(debugScene: "an-set-vendor")
        XCTAssertTrue(element("analytics.settings.vendorStatus").waitForExistence(timeout: 15))
    }

    func testAPriceFindingOpensPricingUnderFromAnalytics() {
        app.launch(debugScene: "an-jump-br")
        XCTAssertTrue(element("analytics.origin").waitForExistence(timeout: 15))
        element("analytics.origin.back").click()
        XCTAssertTrue(element("analytics.findings").waitForExistence(timeout: 10), "Back on What to Try")
    }

    /// A static text's string is its value on macOS; a button's is its label.
    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
