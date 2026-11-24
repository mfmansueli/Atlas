//
//  HelpUITests.swift
//  AtlasUITests
//

import XCTest

/// Atlas Help (board 49) in its DEBUG scenes (the Help window's content in
/// the main window), and the Help menu opening the real window.
@MainActor
final class HelpUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testHomeListsEveryGroup() {
        app.launch(debugScene: "help-home")
        XCTAssertTrue(element("help.home.title").waitForExistence(timeout: 15))
        XCTAssertTrue(element("help.card.connect").exists)
        XCTAssertTrue(element("help.link.fix").exists)
        XCTAssertTrue(element("help.nav.keys").exists)
        XCTAssertTrue(app.buttons["help.contact"].exists)
        XCTAssertFalse(app.buttons["help.back"].isEnabled)
        attach("help-home")
        element("help.card.connect").click()
        XCTAssertTrue(waitForText("Connect App Store Connect", in: element("help.article.title")))
        XCTAssertTrue(app.buttons["help.back"].isEnabled)
    }

    func testATryShowsResultsAndBackReturnsToThem() {
        app.launch(debugScene: "help-home")
        let vendor = app.buttons["help.try.1"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 15))
        vendor.click()
        XCTAssertTrue(waitForText("for “Vendor number”", in: element("help.results.title"), contains: true))
        element("help.result.analytics").click()
        XCTAssertTrue(waitForText("Analytics", in: element("help.article.title")))
        XCTAssertEqual(text(of: element("help.crumb")), "Atlas Help › After release › Analytics")
        app.buttons["help.back"].click()
        XCTAssertTrue(element("help.result.analytics").waitForExistence(timeout: 5))
    }

    func testSearchResults() {
        app.launch(debugScene: "help-search")
        XCTAssertTrue(element("help.results.title").waitForExistence(timeout: 15))
        XCTAssertTrue(element("help.result.analytics").exists)
        attach("help-search")
    }

    func testNothingMatches() {
        app.launch(debugScene: "help-none")
        XCTAssertTrue(element("help.results.none").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("help.results.title")), "No results for “spaceship”")
        attach("help-none")
    }

    func testAnArticleWithStepsShowMeAndRelated() {
        app.launch(debugScene: "help-connect")
        XCTAssertTrue(element("help.article.title").waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["help.showMe"].label, "Show Me: Settings → Accounts")
        XCTAssertTrue(element("help.note").exists)
        attach("help-connect")
        // Link-styled buttons read as links, not buttons.
        element("help.related.fix").click()
        XCTAssertTrue(waitForText("Fix a problem", in: element("help.article.title")))
    }

    /// Show Me opens Settings on the article's pane and says so.
    func testShowMeOpensSettings() {
        app.launch(debugScene: "help-connect")
        let showMe = app.buttons["help.showMe"]
        XCTAssertTrue(showMe.waitForExistence(timeout: 15))
        showMe.click()
        XCTAssertTrue(element("help.shown").waitForExistence(timeout: 5))
        XCTAssertTrue(waitForText("Accounts", in: element("settings.pane.title"), timeout: 10))
    }

    func testTablesAndShortcuts() {
        app.launch(debugScene: "help-assistant")
        XCTAssertTrue(element("help.table").waitForExistence(timeout: 15))
        attach("help-assistant")
        // Keyboard shortcuts is below the sidebar's fold.
        app.outlines.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        let keys = app.buttons["help.nav.keys"]
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: keys)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 5), .completed)
        keys.click()
        XCTAssertTrue(waitForText("Keyboard shortcuts", in: element("help.article.title")))
        XCTAssertFalse(app.buttons["help.showMe"].exists)
        attach("help-keys")
    }

    func testTheShownNote() {
        app.launch(debugScene: "help-shown")
        XCTAssertTrue(element("help.shown").waitForExistence(timeout: 15))
        attach("help-shown")
    }

    /// The Help menu's Keyboard Shortcuts opens the Help window on it.
    func testTheHelpMenuOpensTheHelpWindow() {
        app.launch(debugScene: "help-home")
        XCTAssertTrue(element("help.home.title").waitForExistence(timeout: 15))
        app.menuBars.menuBarItems["Help"].click()
        app.menuItems["Keyboard Shortcuts"].click()
        let window = app.windows["Atlas Help"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let title = window.descendants(matching: .any)["help.article.title"].firstMatch
        XCTAssertTrue(waitForText("Keyboard shortcuts", in: title))
    }

    /// Fix a problem opened at a heading scrolls to it.
    func testFixAProblemOpensAtItsHeading() {
        app.launch(debugScene: "help-fix-heading")
        XCTAssertTrue(waitForText("Fix a problem", in: element("help.article.title"), timeout: 15))
        let heading = app.staticTexts["The key can’t do that"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(heading.isHittable)
        attach("help-fix-heading")
    }

    /// An error's Fix a Problem and a section's ? open the Help window.
    func testFixAProblemAndTheSectionsQuestionMarkOpenHelp() {
        app.launch(debugScene: "help-fix-links")
        let fix = app.descendants(matching: .any).matching(identifier: "help.fixProblem").firstMatch
        XCTAssertTrue(fix.waitForExistence(timeout: 15))
        attach("help-fix-links")
        fix.click()
        let window = app.windows["Atlas Help"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let title = window.descendants(matching: .any)["help.article.title"].firstMatch
        XCTAssertTrue(waitForText("Fix a problem", in: title))

        let help = app.buttons["workspace.help"].firstMatch
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.click()
        XCTAssertTrue(waitForText("Pricing by country", in: title, timeout: 10))
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitForText(_ expected: String, in element: XCUIElement, contains: Bool = false, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            let text = self.text(of: element)
            return contains ? text.contains(expected) : text == expected
        }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
