//
//  AssistantChatUITests.swift
//  AtlasUITests
//

import XCTest

/// The assistant chat in the window's corner (board 69), through the
/// `chat-*` DEBUG scenes in `AssistantChatDebugScenes`: a pretend helper
/// answers every question after two steps, so nothing runs.
@MainActor
final class AssistantChatUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Closed, the pill asks about the app; open, a question works through
    /// steps to an answer; Esc closes it and the draft is kept.
    func testAQuestionIsAnsweredAndADraftIsKept() {
        app.launch(debugScene: "chat-ready")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertEqual(pill.label, "Claude Code, Ask about Lumen Journal…")

        pill.click()
        XCTAssertTrue(element("chat.panel").waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.empty").exists)
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "chat.starter").count, 2)
        XCTAssertTrue(element("chat.chip.version").exists)

        let field = app.textFields["chat.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("Which countries lose the most sales?\r")
        XCTAssertTrue(element("chat.person").waitForExistence(timeout: 5))

        let answer = element("chat.answer")
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: answer).hasPrefix("Brazil, India and Mexico."), text(of: answer))
        XCTAssertTrue(app.buttons["chat.send"].exists)

        // A draft survives closing.
        field.click()
        field.typeText("And India?")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("chat.closed").waitForExistence(timeout: 5))
        XCTAssertFalse(element("chat.panel").exists)
        XCTAssertTrue(waitFor { pill.label.contains("And India?") }, pill.label)
    }

    /// While it works, steps count up and Stop ends the answer.
    func testStopEndsTheAnswer() {
        app.launch(debugScene: "chat-asking")
        let stop = app.buttons["chat.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        XCTAssertTrue(element("chat.steps").waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.working").exists)
        stop.click()
        XCTAssertTrue(element("chat.stopped").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat.send"].exists)
        XCTAssertFalse(element("chat.working").exists)
    }

    /// ⌘J opens and closes the chat from anywhere in the window.
    func testCommandJTogglesTheChat() {
        app.launch(debugScene: "chat-ready")
        XCTAssertTrue(app.buttons["chat.pill"].waitForExistence(timeout: 10))
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(element("chat.panel").waitForExistence(timeout: 5))
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(element("chat.closed").waitForExistence(timeout: 5))
    }

    /// When the assistant asks, the pill says so; a quick reply answers.
    func testAQuickReplyAnswersTheAssistant() {
        app.launch(debugScene: "chat-needs")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor { pill.label.contains("Count every product") }, pill.label)

        pill.click()
        XCTAssertTrue(element("chat.question").waitForExistence(timeout: 5))
        let replies = app.buttons.matching(identifier: "chat.quickReply")
        XCTAssertEqual(replies.count, 2)
        replies.element(boundBy: 0).click()
        XCTAssertTrue(waitFor { app.descendants(matching: .any).matching(identifier: "chat.person").count == 2 })
        XCTAssertTrue(element("chat.answer").waitForExistence(timeout: 20))
    }

    /// A failure is amber with Try Again, which asks once more.
    func testTryAgainAfterAFailure() {
        app.launch(debugScene: "chat-error-open")
        XCTAssertTrue(element("chat.failure").waitForExistence(timeout: 10))
        app.buttons["chat.retry"].click()
        XCTAssertTrue(element("chat.answer").waitForExistence(timeout: 20))
        XCTAssertFalse(element("chat.failure").exists)
    }

    /// Without an assistant there is nothing to ask: Connect… opens setup.
    func testWithoutAnAssistantItOffersConnect() {
        app.launch(debugScene: "chat-none")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor { pill.label.contains("No assistant connected") }, pill.label)
        let connect = app.buttons["chat.pill.action"]
        XCTAssertTrue(connect.exists)
        connect.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
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
}
