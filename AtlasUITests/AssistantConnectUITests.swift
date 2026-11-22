//
//  AssistantConnectUITests.swift
//  AtlasUITests
//

import XCTest

/// Board 48's Connect (November 22): the assistants found on this Mac,
/// the three-step sheet and the row right after connecting, opened by the
/// `set-assistants-*` and `set-wiz-*` DEBUG scenes. The scenes' assistants
/// and helper are pretend: nothing is written to a real assistant's
/// settings, and Send a Test Suggestion copies nothing.
@MainActor
final class AssistantConnectUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - The list

    func testTheAssistantsFoundEachHaveConnect() {
        app.launch(debugScene: "set-assistants-new")
        XCTAssertTrue(app.buttons["settings.ai.connect.claudeCode"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.ai.connect.claudeForMac"].exists)
        XCTAssertTrue(app.buttons["settings.ai.connect.cursor"].exists)
        XCTAssertTrue(element("settings.ai.howItWorks").exists)
        // Local server and Pair Assistant… wait under Advanced.
        XCTAssertFalse(element("settings.ai.server").exists)
        XCTAssertFalse(app.buttons["settings.ai.pair"].exists)
        attach("set-assistants-new")
    }

    func testJustConnectedShowsWhatToTryAndTheTest() {
        app.launch(debugScene: "set-assistants-done")
        let test = app.buttons["settings.ai.test.claudeCode"]
        XCTAssertTrue(test.waitForExistence(timeout: 15))
        XCTAssertTrue(element("settings.ai.try.claudeCode").exists)
        XCTAssertTrue(text(of: element("settings.ai.assistant.claudeCode.status")).hasPrefix("Connected just now"))
        attach("set-assistants-done")
        test.click()
        // The pretend Claude Code makes its suggestion and the button says so.
        XCTAssertTrue(waitUntil(timeout: 10) { !test.isEnabled })
    }

    func testAdvancedHasTheServerAndTheLineToPaste() {
        app.launch(debugScene: "set-assistants-adv")
        XCTAssertTrue(element("settings.ai.server").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.ai.pair"].exists)
        XCTAssertTrue(text(of: element("settings.ai.byHandLine")).contains("atlas-mcp"))
        XCTAssertTrue(app.buttons["settings.ai.byHandCopy"].exists)
        attach("set-assistants-adv")
        app.buttons["settings.ai.advanced"].click()
        XCTAssertTrue(element("settings.ai.server").waitForNonExistence(timeout: 5))
    }

    // MARK: - Step 1: the project folder

    func testStepOneOffersTheFolderAtlasFound() {
        app.launch(debugScene: "set-wiz-folder")
        XCTAssertTrue(sheet.waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("settings.connect.stepCount")), "Step 1 of 3")
        XCTAssertTrue(element("settings.connect.drop").exists)
        XCTAssertTrue(app.buttons["settings.connect.chooseFolder"].exists)
        XCTAssertFalse(app.buttons["settings.connect.connect"].isEnabled)
        XCTAssertTrue(app.buttons["settings.connect.withoutProject"].isEnabled)
        attach("set-wiz-folder")
        app.buttons["settings.connect.useSuggestion"].click()
        XCTAssertTrue(element("settings.connect.folder").waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.connect.checks").exists)
        XCTAssertTrue(app.buttons["settings.connect.connect"].isEnabled)
    }

    func testADraggedFolderLightsTheDropArea() {
        app.launch(debugScene: "set-wiz-drag")
        XCTAssertTrue(element("settings.connect.drop.over").waitForExistence(timeout: 15))
        attach("set-wiz-drag")
    }

    func testAWrongFolderSaysWhatIsMissing() {
        app.launch(debugScene: "set-wiz-wrong")
        let wrong = element("settings.connect.wrongFolder")
        XCTAssertTrue(wrong.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Downloads", "Downloads")).firstMatch.exists)
        XCTAssertFalse(app.buttons["settings.connect.connect"].isEnabled)
        attach("set-wiz-wrong")
    }

    /// Connect on a picked folder plays steps 2 and 3 with the pretend
    /// helper: the hello is typed, then arrives.
    func testConnectAddsStartsAndSaysHello() {
        app.launch(debugScene: "set-wiz-picked")
        let connect = app.buttons["settings.connect.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 15))
        XCTAssertTrue(element("settings.connect.checks").exists)
        attach("set-wiz-picked")
        connect.click()
        XCTAssertTrue(element("settings.connect.progress.1").waitForExistence(timeout: 5))
        XCTAssertTrue(element("motion.typing").waitForExistence(timeout: 15))
        XCTAssertTrue(element("settings.connect.helloText").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("settings.connect.stepCount")), "Step 3 of 3")
        XCTAssertTrue(app.buttons["settings.connect.firstSuggestion"].exists)
        app.buttons["settings.connect.done"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.ai.test.claudeCode"].waitForExistence(timeout: 5))
    }

    // MARK: - Steps 2 and 3

    func testStepTwoShowsEachStep() {
        app.launch(debugScene: "set-wiz-busy")
        XCTAssertTrue(element("settings.connect.progress.2").waitForExistence(timeout: 15))
        XCTAssertTrue(element("settings.connect.progress.1").exists)
        XCTAssertTrue(element("settings.connect.progress.3").exists)
        attach("set-wiz-busy")
    }

    func testTheHelloHasThingsToAsk() {
        app.launch(debugScene: "set-wiz-hello")
        XCTAssertTrue(element("settings.connect.helloText").waitForExistence(timeout: 15))
        XCTAssertTrue(element("settings.connect.thingsToAsk").exists)
        XCTAssertTrue(app.buttons["settings.connect.firstSuggestion"].exists)
        attach("set-wiz-hello")
    }

    func testNoAnswerGivesEachReasonAButton() {
        app.launch(debugScene: "set-wiz-fail")
        XCTAssertTrue(element("settings.connect.reasons").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.connect.reason.restart"].exists)
        XCTAssertTrue(app.buttons["settings.connect.reason.open"].exists)
        XCTAssertTrue(app.buttons["settings.connect.reason.help"].exists)
        XCTAssertTrue(app.buttons["settings.connect.tryAgain"].exists)
        attach("set-wiz-fail")
        app.buttons["settings.connect.cancel"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    // MARK: - Helpers

    private var sheet: XCUIElement {
        element("settings.connect.sheet")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func waitUntil(timeout: TimeInterval, _ check: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in check() }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
