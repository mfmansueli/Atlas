//
//  WelcomeUITests.swift
//  AtlasUITests
//

import XCTest

/// The first run (board 45): Welcome, Connect under the compact header,
/// and Reading your apps, through the DEBUG scenes in
/// `ConnectDebugScenes` (canned key checks, no Keychain, no Apple).
@MainActor
final class WelcomeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testGetStartedOpensConnectAndBackKeepsWhatWasTyped() {
        app.launch(debugScene: "welcome")
        XCTAssertTrue(element("welcome.title").waitForExistence(timeout: 10))
        XCTAssertTrue(element("welcome.header").exists)
        app.buttons["welcome.getStarted"].click()

        let issuer = app.textFields["connect.issuerIDField"]
        XCTAssertTrue(issuer.waitForExistence(timeout: 5))
        XCTAssertTrue(element("connect.title").exists)
        XCTAssertFalse(app.buttons["connect.connectButton"].isEnabled)
        issuer.click()
        issuer.typeText("69a6de7f-3c2e-47e3-e053-5b8c7c11a4d1")

        app.buttons["connect.backButton"].click()
        XCTAssertTrue(element("welcome.title").waitForExistence(timeout: 5))
        XCTAssertFalse(issuer.exists)

        app.buttons["welcome.getStarted"].click()
        XCTAssertTrue(issuer.waitForExistence(timeout: 5))
        XCTAssertEqual(issuer.value as? String, "69a6de7f-3c2e-47e3-e053-5b8c7c11a4d1")
    }

    func testReduceMotionWelcomeHasTheSameWords() {
        app.launch(debugScene: "welcome-still")
        XCTAssertTrue(element("welcome.title").waitForExistence(timeout: 10))
        XCTAssertTrue(element("welcome.header").exists)
        XCTAssertTrue(app.buttons["welcome.getStarted"].exists)
        // The chips are decoration: VoiceOver doesn't read them.
        XCTAssertFalse(app.staticTexts["Deutsch"].exists)
    }

    func testReadingYourAppsCountsTheAppsAndCancelGoesBackToWelcome() {
        app.launch(debugScene: "sync")
        XCTAssertTrue(element("sync.title").waitForExistence(timeout: 10))
        let summary = element("sync.summary")
        XCTAssertTrue(summary.exists)
        let text = (summary.value as? String) ?? summary.label
        XCTAssertTrue(text.hasPrefix("Found 6 apps in Northpier Studio."), text)
        XCTAssertTrue(text.hasSuffix("Nothing is changed in App Store Connect."), text)
        XCTAssertTrue(element("sync.progress").exists)

        app.buttons["sync.cancel"].click()
        XCTAssertTrue(element("welcome.title").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
