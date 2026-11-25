//
//  AutoReplyUITests.swift
//  AtlasUITests
//

import XCTest

/// Reply Automatically (board 58), driven through `AutoReplyDebugScenes`:
/// turning it on from its settings, the strip's Pause, History's Undo, a
/// reply that goes out by itself, and Free's Upgrade…. Each test attaches
/// the window's screenshot.
@MainActor
final class AutoReplyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTurningItOnShowsTheStrip() {
        app.launch(debugScene: "ar-settings")
        let save = element("autoReply.save")
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        XCTAssertTrue(element("autoReply.example").exists, "The tone shows an example")
        attachScreenshot("Reply Automatically…")
        save.click()
        let title = element("autoReply.strip.title")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: title), "Replying automatically")
        XCTAssertEqual(text(of: element("autoReply.strip.detail")), "Drafts a reply to each new review and tells you")
        attachScreenshot("Auto-reply on")
    }

    func testPauseAndResumeFromTheStrip() {
        app.launch(debugScene: "ar")
        let pause = element("autoReply.strip.pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        let strip = element("autopilotBar.strip")
        // The Autopilot bar's strip says what needs the person.
        XCTAssertTrue(waitUntil { strip.label.contains("1 Review Needs You") }, strip.label)
        pause.click()
        XCTAssertTrue(waitUntil { self.text(of: self.element("autoReply.strip.title")) == "Auto-reply is paused" })
        attachScreenshot("Auto-reply paused")
        element("autoReply.strip.pause").click()
        XCTAssertTrue(waitUntil { self.text(of: self.element("autoReply.strip.title")) == "Replying automatically" })
    }

    func testAReplyThatGoesOutByItselfSaysWhen() {
        app.launch(debugScene: "ar")
        let line = element("reviews.suggestion.auto.r-br1")
        XCTAssertTrue(line.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: line).hasPrefix("Sends by itself in "), text(of: line))
        XCTAssertEqual(text(of: element("reviews.suggestion.auto.r-jp1")), "Waits for you: 2★ replies wait for you")
        let send = element("reviews.suggestion.send.r-br1")
        XCTAssertEqual(send.label.isEmpty ? text(of: send) : send.label, "Send Now")
        let dontSend = element("reviews.suggestion.dontSend.r-br1")
        dontSend.click()
        XCTAssertTrue(waitUntil { self.text(of: line).hasPrefix("Won’t go out by itself") }, text(of: line))
    }

    func testUndoTakesAReplyBack() {
        app.launch(debugScene: "ar-history")
        let undo = element("autoReply.history.undo.r-gb1")
        XCTAssertTrue(undo.waitForExistence(timeout: 15))
        attachScreenshot("History")
        undo.click()
        let undone = NSPredicate(format: "value BEGINSWITH %@ OR label BEGINSWITH %@", "Undone ", "Undone ")
        XCTAssertTrue(app.staticTexts.matching(undone).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(undo.exists)
    }

    func testFreeSeesWhatProDoes() {
        app.launch(debugScene: "ar-free")
        let upgrade = element("autoReply.upgrade")
        XCTAssertTrue(upgrade.waitForExistence(timeout: 15))
        XCTAssertTrue(element("autoReply.free").exists)
        XCTAssertFalse(element("autoReply.save").isEnabled, "Turn On waits for Pro")
        attachScreenshot("Reply Automatically on Free")
    }

    // MARK: - Helpers

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
