//
//  TourUITests.swift
//  AtlasUITests
//

import XCTest

/// The first-run tour and the sidebar's new rows (board 63): five tips one
/// at a time, Skip the Tour, the last tip's Connect an Assistant…, the
/// Settings row and Show the Tour.
@MainActor
final class TourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// A first run starts the tour by itself; Next four times walks it,
    /// Done ends it.
    func testTheFirstRunWalksTheFiveTipsToDone() {
        app.launch(debugScene: "tour")
        XCTAssertTrue(tip(1).waitForExistence(timeout: 15), "The tour started by itself")
        XCTAssertTrue(waitForText("Your apps are here", in: element("tour.title")))
        XCTAssertEqual(text(of: element("tour.count")), "1 of 5")
        attach("tour")
        let titles = [
            "Each section is a part of your App Store page", "Let your assistant do the work", "Nothing changes until you push",
            "Settings are always here",
        ]
        for (index, title) in titles.enumerated() {
            let number = index + 2
            nextButton.click()
            XCTAssertTrue(tip(number).waitForExistence(timeout: 5), "Tip \(number)")
            XCTAssertTrue(waitForText(title, in: element("tour.title")))
            XCTAssertEqual(text(of: element("tour.count")), "\(number) of 5")
            attach("tour-\(number)")
        }
        XCTAssertEqual(nextButton.label, "Done")
        XCTAssertEqual(alternativeButton.label, "Connect an Assistant…")
        nextButton.click()
        XCTAssertTrue(tip(5).waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("tour.title").exists)
    }

    func testSkipTheTourEndsIt() {
        app.launch(debugScene: "tour")
        XCTAssertTrue(tip(1).waitForExistence(timeout: 15))
        XCTAssertEqual(alternativeButton.label, "Skip the Tour")
        alternativeButton.click()
        XCTAssertTrue(tip(1).waitForNonExistence(timeout: 5))
        XCTAssertFalse(tip(2).exists)
    }

    func testTheCloseButtonEndsTheTour() {
        app.launch(debugScene: "tour-3")
        XCTAssertTrue(tip(3).waitForExistence(timeout: 15))
        XCTAssertTrue(waitForText("Let your assistant do the work", in: element("tour.title")))
        app.buttons["tour.close"].firstMatch.click()
        XCTAssertTrue(tip(3).waitForNonExistence(timeout: 5))
        XCTAssertFalse(tip(4).exists)
    }

    /// The last tip's Connect an Assistant… ends the tour on Settings → AI
    /// Assistants.
    func testTheLastTipConnectsAnAssistant() {
        app.launch(debugScene: "tour-5")
        XCTAssertTrue(tip(5).waitForExistence(timeout: 15))
        alternativeButton.click()
        XCTAssertTrue(waitForText("AI Assistants", in: element("settings.pane.title"), timeout: 10))
        XCTAssertFalse(tip(5).exists)
    }

    func testTheSettingsRowOpensSettings() {
        app.launch(debugScene: "nav-ov")
        let settings = element("sidebar.settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        XCTAssertEqual(settings.label, "Settings")
        attach("nav-ov-settings-row")
        settings.click()
        XCTAssertTrue(element("settings.pane.title").waitForExistence(timeout: 10))
    }

    /// Help ▾ → Show the Tour starts again from the first tip, on Overview.
    func testShowTheTourStartsItAgain() {
        app.launch(debugScene: "nav-sp")
        let help = element("sidebar.help")
        XCTAssertTrue(help.waitForExistence(timeout: 15))
        XCTAssertFalse(tip(1).exists, "Scenes other than the tour's don't start it")
        help.click()
        let showTour = help.menuItems["Show the Tour"]
        XCTAssertTrue(showTour.waitForExistence(timeout: 5))
        showTour.click()
        XCTAssertTrue(tip(1).waitForExistence(timeout: 5))
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
        nextButton.click()
        XCTAssertTrue(tip(2).waitForExistence(timeout: 5))
    }

    /// The switcher's last line counts the other apps.
    func testTheSwitcherSaysHowManyOtherAppsThereAre() {
        app.launch(debugScene: "nav-ov")
        let switcher = element("sidebar.appSwitcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 15))
        let counted = NSPredicate(format: "label CONTAINS %@", "other app")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: counted, object: switcher)], timeout: 10), .completed, switcher.label)
        XCTAssertTrue(switcher.label.hasPrefix("App: Lumen"), switcher.label)
        XCTAssertEqual(switcher.value as? String, "Northpier Studio · Admin")
    }

    // MARK: - Helpers

    private func tip(_ number: Int) -> XCUIElement {
        element("tour.tip.\(number)")
    }

    private var nextButton: XCUIElement {
        app.buttons["tour.next"].firstMatch
    }

    private var alternativeButton: XCUIElement {
        app.buttons["tour.alternative"].firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitForText(_ text: String, in element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
