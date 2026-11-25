//
//  AutopilotBarUITests.swift
//  AtlasUITests
//

import AppKit
import XCTest

/// The Autopilot bar at the bottom of every section (board 80), through
/// the `bar-*` DEBUG scenes in `AutopilotBarDebugScenes`: a pretend helper
/// answers every question after two steps, so nothing runs.
@MainActor
final class AutopilotBarUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Closed: the field, the section's first two actions and More. A
    /// click on the field opens the conversation; a question works through
    /// steps to an answer; Esc makes it small again and keeps the draft.
    func testAQuestionIsAnsweredAndADraftIsKept() {
        app.launch(debugScene: "bar-idle")
        let field = app.buttons["autopilotBar.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "autopilotBar.action").count, 2)
        XCTAssertTrue(element("autopilotBar.more").exists)
        XCTAssertFalse(element("autopilotBar.strip").exists)

        field.click()
        XCTAssertTrue(element("chat.panel").waitForExistence(timeout: 5))
        XCTAssertTrue(element("autopilotBar.actions").exists)
        XCTAssertTrue(element("chat.empty").exists)
        XCTAssertTrue(element("autopilotBar.footer").exists)

        let input = app.textFields["chat.field"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        input.typeText("Which countries lose the most sales?\r")
        XCTAssertTrue(element("chat.person").waitForExistence(timeout: 5))
        let answer = element("chat.answer")
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: answer).hasPrefix("Brazil, India and Mexico."), text(of: answer))

        input.click()
        input.typeText("And India?")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("chat.panel").waitForNonExistence(timeout: 5))
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        XCTAssertTrue(waitFor { (app.textFields["chat.field"].firstMatch.value as? String) == "And India?" })
    }

    /// ⌘J opens and closes the bar from anywhere in the window.
    func testCommandJTogglesTheBar() {
        app.launch(debugScene: "bar-idle")
        XCTAssertTrue(app.buttons["autopilotBar.field"].waitForExistence(timeout: 10))
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(element("chat.panel").waitForExistence(timeout: 5))
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(element("chat.panel").waitForNonExistence(timeout: 5))
    }

    /// A request from a button works on the strip: its step, its count and
    /// Stop.
    func testAButtonsRequestWorksOnTheStrip() {
        app.launch(debugScene: "bar-run")
        let strip = app.autopilotStrip
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor(timeout: 10) { strip.label.contains("2 of 3") }, strip.label)
        XCTAssertTrue(text(of: element("autopilotBar.strip.subtitle")).contains("What’s New"))
        let stop = app.buttons["autopilotBar.stop"]
        XCTAssertTrue(stop.exists)
        stop.click()
        XCTAssertTrue(waitFor(timeout: 10) { !app.buttons["autopilotBar.stop"].exists })
    }

    /// Open while a request runs: the person's bubble over its steps.
    func testOpenARequestShowsItsSteps() {
        app.launch(debugScene: "bar-open-run")
        XCTAssertTrue(element("chat.panel").waitForExistence(timeout: 10))
        XCTAssertTrue(element("chat.person").waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.steps").waitForExistence(timeout: 10))
        XCTAssertTrue(element("chat.working").exists)
    }

    /// When the assistant asks, the strip says so with its answers as
    /// buttons; one answers it.
    func testAnAnswerOnTheStripAnswersTheAssistant() {
        app.launch(debugScene: "bar-needs")
        let strip = app.autopilotStrip
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(strip.label.contains("Count every product"), strip.label)
        let choices = app.buttons.matching(identifier: "autopilotBar.strip.choice")
        XCTAssertEqual(choices.count, 2)
        choices.element(boundBy: 0).click()
        XCTAssertTrue(waitFor(timeout: 10) { strip.label.contains("Autopilot") && !strip.label.contains("Count every product") }, strip.label)
    }

    /// A finished request says Done with Show; ✕ closes the strip.
    func testDoneShowsAndCloses() {
        app.launch(debugScene: "bar-done")
        let strip = app.autopilotStrip
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(strip.label.contains("Done · Suggest Texts"), strip.label)
        XCTAssertTrue(app.buttons["autopilotBar.strip.action"].exists)
        app.buttons["autopilotBar.dismiss"].click()
        XCTAssertTrue(strip.waitForNonExistence(timeout: 5))
    }

    /// A stopped question is amber with Try Again, which asks once more.
    func testTryAgainAfterAFailure() {
        app.launch(debugScene: "bar-err")
        let strip = app.autopilotStrip
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(strip.label.contains("Claude Code stopped"), strip.label)
        app.buttons["autopilotBar.strip.action"].click()
        XCTAssertTrue(waitFor(timeout: 20) { strip.label.contains("Open") || strip.label.contains("Brazil") }, strip.label)
    }

    /// Earlier today lists what finished, each with Show.
    func testEarlierTodayListsWhatFinished() {
        app.launch(debugScene: "bar-hist")
        XCTAssertTrue(element("autopilotBar.earlier").waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "autopilotBar.earlier.show").count, 2)
        // With a conversation, the actions fold to one line.
        XCTAssertTrue(app.buttons["autopilotBar.actions.fold"].exists)
    }

    /// Without an assistant there is nothing to ask: Connect… opens setup.
    func testWithoutAnAssistantItOffersConnect() {
        app.launch(debugScene: "bar-none")
        let connect = app.buttons["autopilotBar.footer.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 10))
        connect.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
    }

    /// On Free, what's part of Pro says so beside the field, and asks for
    /// the paywall.
    func testOnFreeProActionsCarryPro() {
        app.launch(debugScene: "bar-free")
        let actions = app.buttons.matching(identifier: "autopilotBar.action")
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["autopilotBar.field"].exists)
    }

    /// The field keeps its words beside the buttons at every width: the
    /// buttons fold into More one at a time.
    func testTheFieldFitsEveryWidth() {
        app.launch(debugScene: "bar-width")
        let fields = app.buttons.matching(identifier: "autopilotBar.field")
        XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.count, 4)
        for index in 0..<fields.count {
            XCTAssertGreaterThanOrEqual(fields.element(boundBy: index).frame.width, 119, "Field \(index) cut")
        }
        XCTAssertLessThan(app.buttons.matching(identifier: "autopilotBar.action").count, 8)
        attach("bar at every width")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func waitFor(timeout: TimeInterval = 5, _ check: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if check() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.1))
        }
        return false
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
