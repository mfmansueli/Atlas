//
//  AssistantChatUITests.swift
//  AtlasUITests
//

import AppKit
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
        XCTAssertEqual(pill.label, "Claude Code: Ask about Lumen Journal…")

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

    /// Right after asking, before Claude Code reports a step, the pill says
    /// it's sending, with nothing counted and so no bar; the open panel
    /// lists the same line.
    func testSendingHasNoCountAndNoBar() {
        app.launch(debugScene: "chat-sending")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor { pill.label == "Claude Code: Sending to Claude Code…" }, pill.label)
        // The count is the pill's value, shown only with its bar.
        XCTAssertEqual(pill.value as? String ?? "", "")
        XCTAssertFalse(pill.label.contains(" of "), pill.label)

        pill.click()
        let steps = element("chat.steps")
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        XCTAssertEqual(steps.label, "Claude Code: Sending to Claude Code…")
    }

    /// The last step writes the answer: every step done, 3 of 3.
    func testTheLastStepWritesTheAnswer() {
        app.launch(debugScene: "chat-writing")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor(timeout: 10) { pill.label == "Claude Code: Writing the answer…" }, pill.label)
        XCTAssertTrue(waitFor { pill.value as? String == "3 of 3" }, pill.value as? String ?? "no value")
    }

    /// While a step runs, the pill counts it with the answer still to write.
    func testWorkingCountsTheSteps() {
        app.launch(debugScene: "chat-working")
        let pill = app.buttons["chat.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor(timeout: 10) { pill.value as? String == "2 of 3" }, pill.value as? String ?? "no value")
        XCTAssertTrue(pill.label.hasPrefix("Claude Code: Read"), pill.label)
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

    /// An answer that queued a new version and its What's New points to
    /// Review & Push, where they wait until the push creates the version.
    func testANewVersionAnswerOpensReviewAndPush() {
        app.launch(debugScene: "chat-version")
        let review = app.buttons["chat.suggestions.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["chat.suggestions.show"].exists)
        XCTAssertEqual(text(of: element("chat.suggestions.title")), "2 suggestions in Review & Push")
        XCTAssertTrue(text(of: element("chat.note")).hasPrefix("They wait in Review & Push."), text(of: element("chat.note")))
        review.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
    }

    /// What the person wrote and what came back can be selected with the
    /// mouse and copied.
    func testMessagesCanBeSelectedAndCopied() {
        app.launch(debugScene: "chat-version")
        let person = element("chat.person")
        let answer = element("chat.answer")
        XCTAssertTrue(answer.waitForExistence(timeout: 10))
        // A double-click on each message's first word, then ⌘C.
        for (message, word, inset) in [(person, "Create", CGVector(dx: 22, dy: 12)), (answer, "Version", CGVector(dx: 12, dy: 8))] {
            NSPasteboard.general.clearContents()
            message.coordinate(withNormalizedOffset: .zero).withOffset(inset).doubleClick()
            app.typeKey("c", modifierFlags: .command)
            XCTAssertTrue(waitFor { NSPasteboard.general.string(forType: .string) == word }, NSPasteboard.general.string(forType: .string) ?? "nothing copied")
        }
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
