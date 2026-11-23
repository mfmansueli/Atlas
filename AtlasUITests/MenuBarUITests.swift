//
//  MenuBarUITests.swift
//  AtlasUITests
//

import XCTest

/// The menu bar's menu and the "still running" note (board 46), shown in
/// the window by the DEBUG scenes in `MenuBarDebugScenes`: a scene has
/// no menu bar icon, and its lines act on the scene.
@MainActor
final class MenuBarUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testRunningShowsEachJobAndWhatNeedsYou() {
        app.launch(debugScene: "mb-running")
        XCTAssertTrue(element("menuBar.job.push").waitForExistence(timeout: 10))
        XCTAssertTrue(element("menuBar.job.autopilot").exists)
        XCTAssertTrue(element("menuBar.need.release-6450000001").exists)
        XCTAssertFalse(element("menuBar.quietTitle").exists)
        XCTAssertTrue(app.buttons["menuBar.reviewPush"].exists)
    }

    func testANeedOpensAtlasAtItsPlace() {
        app.launch(debugScene: "mb-needs")
        let need = app.buttons["menuBar.need.release-6450000001"]
        XCTAssertTrue(need.waitForExistence(timeout: 10))
        need.click()
        XCTAssertEqual(lastAction(), "Open the version of 6450000001")
    }

    func testQuietSaysEverythingIsUpToDate() {
        app.launch(debugScene: "mb-quiet")
        let title = element("menuBar.quietTitle")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: title), "Everything is up to date")
        XCTAssertEqual(text(of: element("menuBar.checkLine")), "Last checked today at 18:20 · next check at 19:20")
    }

    func testPauseAndResumeBackgroundWork() {
        app.launch(debugScene: "mb-quiet")
        let pause = app.buttons["menuBar.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        pause.click()
        XCTAssertEqual(lastAction(), "Paused")
        XCTAssertEqual(text(of: element("menuBar.quietTitle")), "Background work is paused")
        pause.click()
        XCTAssertEqual(lastAction(), "Resumed")
        XCTAssertEqual(text(of: element("menuBar.quietTitle")), "Everything is up to date")
    }

    /// Board 58: Reply Automatically on, a review left for the person and
    /// Pause Auto-Reply.
    func testPauseAutoReplyFromTheMenuBar() {
        app.launch(debugScene: "mb-autoreply")
        let pause = app.buttons["menuBar.autoReplyPause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertTrue(element("menuBar.need.autoreply-lumen").exists)
        pause.click()
        XCTAssertEqual(lastAction(), "Auto-reply paused")
        pause.click()
        XCTAssertEqual(lastAction(), "Auto-reply resumed")
    }

    func testNoAutoReplyLineWhileItsOff() {
        app.launch(debugScene: "mb-quiet")
        XCTAssertTrue(app.buttons["menuBar.pause"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["menuBar.autoReplyPause"].exists)
    }

    func testCheckNowShowsTheCheckWhileItRuns() {
        app.launch(debugScene: "mb-quiet")
        let checkNow = app.buttons["menuBar.checkNow"]
        XCTAssertTrue(checkNow.waitForExistence(timeout: 10))
        checkNow.click()
        XCTAssertTrue(element("menuBar.job.check").waitForExistence(timeout: 2))
        XCTAssertTrue(element("menuBar.job.check").waitForNonExistence(timeout: 10))
        XCTAssertEqual(text(of: element("menuBar.checkLine")), "Last checked just now · next check in 1 hour")
    }

    func testCantConnectSaysWhy() {
        app.launch(debugScene: "mb-offline")
        let title = element("menuBar.quietTitle")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: title), "App Store Connect rejected this key (401).")
    }

    func testStillRunningNoteGotIt() {
        app.launch(debugScene: "mb-note")
        let gotIt = app.buttons["stillRunning.gotIt"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["stillRunning.quitWhenClosed"].exists)
        gotIt.click()
        XCTAssertTrue(element("stillRunning.note").waitForNonExistence(timeout: 5))
        XCTAssertEqual(lastAction(), "Got It")
    }

    func testStillRunningNoteCanTurnKeepRunningOff() {
        app.launch(debugScene: "mb-note")
        let quit = app.buttons["stillRunning.quitWhenClosed"]
        XCTAssertTrue(quit.waitForExistence(timeout: 10))
        quit.click()
        XCTAssertEqual(lastAction(), "Quit When Window Closes")
    }

    func testGlyphsInEveryState() {
        app.launch(debugScene: "mb-glyphs")
        XCTAssertTrue(element("glyph.Idle").waitForExistence(timeout: 10))
        for state in ["Working", "Needs you", "Paused", "Can’t connect"] {
            XCTAssertTrue(element("glyph.\(state)").exists, state)
        }
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A Text's words: macOS exposes them as its value.
    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func lastAction() -> String {
        text(of: element("menuBarScene.lastAction"))
    }
}
