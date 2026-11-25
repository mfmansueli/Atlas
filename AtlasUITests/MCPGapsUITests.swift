//
//  MCPGapsUITests.swift
//  AtlasUITests
//

import XCTest

/// What the second round of MCP gaps shows, driven through
/// `MCPGapsDebugScenes`: a pricing strategy an assistant suggested,
/// accepted or dismissed at the top of Pricing, and a new text for a
/// published review reply, read as Now | New and sent with Replace Reply.
/// Each test attaches the window's screenshot.
@MainActor
final class MCPGapsUITests: XCTestCase {
    private var app: XCUIApplication!
    /// The British review whose reply the scene suggests replacing.
    private let review = "r-gb1"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Pricing strategy

    func testAStrategySuggestionCanBeAccepted() {
        app.launch(debugScene: "pr-strategy")
        let card = element("pricing.strategySuggestion")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pricing.strategySuggestion.why").exists, "The card says why")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'pricing.strategySuggestion.row.'")).count > 0,
                      "The card lists what changes")
        attachScreenshot("Pricing strategy suggested")
        element("pricing.strategySuggestion.accept").click()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Accepting takes the card away")
        attachScreenshot("Pricing strategy accepted")
    }

    func testAStrategySuggestionCanBeDismissed() {
        app.launch(debugScene: "pr-strategy")
        let card = element("pricing.strategySuggestion")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        element("pricing.strategySuggestion.dismiss").click()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Dismissing takes the card away")
    }

    // MARK: - Review reply replacement

    func testAReplacementShowsNowAndNewAndSendsAsReplaceReply() {
        app.launch(debugScene: "rv-replace")
        let box = element("reviews.suggestion.\(review)")
        XCTAssertTrue(box.waitForExistence(timeout: 15))
        XCTAssertTrue(element("reviews.replacement.why.\(review)").exists, "The replacement says why")
        let send = element("reviews.suggestion.send.\(review)")
        XCTAssertEqual(send.label.isEmpty ? text(of: send) : send.label, "Replace Reply")
        attachScreenshot("Replacement · New")

        let picker = element("reviews.replacement.version.\(review)")
        picker.radioButtons["Now"].click()
        XCTAssertTrue(element("reviews.replacement.now.\(review)").waitForExistence(timeout: 5), "Now shows the published reply")
        XCTAssertFalse(element("reviews.suggestion.text.\(review)").exists, "Now hides the new text")
        attachScreenshot("Replacement · Now")

        picker.radioButtons["New"].click()
        XCTAssertTrue(element("reviews.suggestion.text.\(review)").waitForExistence(timeout: 5), "New shows the new text")
        XCTAssertFalse(element("reviews.replacement.now.\(review)").exists)
    }

    // MARK: - Helpers

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
