//
//  ScreenshotsByHandUITests.swift
//  AtlasUITests
//

import XCTest

/// Screenshots by hand on the language page (`ScreenshotsHandDebugScenes`):
/// select a screenshot and move it, replace and delete it through their
/// sheets, the Add tile and Manage, a language that uses the primary
/// one's, and an assistant's file, removal and new order to accept or
/// dismiss.
@MainActor
final class ScreenshotsByHandUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testSelectingAScreenshotShowsItsBar() {
        app.launch(debugScene: "hand-page")
        let line = element("screenshots.hand.deviceLine")
        XCTAssertTrue(line.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: line).hasPrefix("iPhone 6.9″ · 1320 × 2868 · 5 of 10."), text(of: line))
        XCTAssertTrue(element("screenshots.hand.addTile").exists, "The Add tile ends the set")
        element("screenshots.page.shot.1").click()
        let bar = element("screenshots.hand.selectionBar")
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(element("screenshots.hand.replace").exists)
        XCTAssertTrue(element("screenshots.hand.delete").exists)
        XCTAssertFalse(element("screenshots.hand.undo").exists, "Nothing to undo yet")
        attachScreenshot("Screenshot 2 selected")
        element("screenshots.hand.moveRight").click()
        let moved = element("screenshots.page.shot.2")
        XCTAssertTrue(waitUntil { self.text(of: moved).hasSuffix("selected") }, "The selection follows the screenshot: \(text(of: moved))")
        element("screenshots.hand.deselect").click()
        XCTAssertTrue(line.waitForExistence(timeout: 5))
    }

    func testReplacingWithAFileThatFits() {
        app.launch(debugScene: "hand-replace")
        let sheet = element("screenshots.hand.replaceSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 20))
        XCTAssertTrue(element("screenshots.hand.note").exists, "Says a render won't be redrawn once replaced")
        let okButton = element("screenshots.hand.sheet.ok")
        XCTAssertTrue(okButton.isEnabled)
        attachScreenshot("Replace Screenshot 2")
        okButton.click()
        XCTAssertTrue(waitUntil { !sheet.exists })
        let origin = element("screenshots.hand.origin")
        XCTAssertTrue(origin.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: origin).hasPrefix("Replaced by you with Lumen-de-02.png"), text(of: origin))
        XCTAssertTrue(element("screenshots.hand.undo").exists)
    }

    func testAWrongSizeCantReplace() {
        app.launch(debugScene: "hand-replace-wrong")
        XCTAssertTrue(element("screenshots.hand.replaceSheet").waitForExistence(timeout: 20))
        let problem = element("screenshots.hand.replace.problem")
        XCTAssertTrue(problem.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: problem).contains("1179 × 2556"), text(of: problem))
        XCTAssertFalse(element("screenshots.hand.sheet.ok").isEnabled)
    }

    func testDeletingMarksTheScreenshot() {
        app.launch(debugScene: "hand-delete")
        let sheet = element("screenshots.hand.deleteSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 20))
        let explanation = element("screenshots.hand.delete.explanation")
        XCTAssertTrue(text(of: explanation).contains("keeps 4 iPhone 6.9″ screenshots"), text(of: explanation))
        element("screenshots.hand.sheet.ok").click()
        XCTAssertTrue(waitUntil { !sheet.exists })
        let shot = element("screenshots.page.shot.1")
        XCTAssertTrue(waitUntil { self.text(of: shot).contains("Will be deleted") }, text(of: shot))
    }

    func testAddingSkipsTheWrongSize() {
        app.launch(debugScene: "hand-add")
        XCTAssertTrue(element("screenshots.hand.addSheet").waitForExistence(timeout: 20))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "screenshots.hand.add.file").count, 3)
        let okButton = element("screenshots.hand.sheet.ok")
        XCTAssertEqual(text(of: okButton), "Add 2")
        attachScreenshot("Add Screenshots")
        okButton.click()
        let line = element("screenshots.hand.deviceLine")
        XCTAssertTrue(waitUntil { self.text(of: line).contains("7 of 10") }, text(of: line))
    }

    func testManageHasImportAndDeleteAll() {
        app.launch(debugScene: "hand-page")
        let manage = element("screenshots.hand.manage")
        XCTAssertTrue(manage.waitForExistence(timeout: 20))
        manage.click()
        XCTAssertTrue(app.menuItems["Import a Folder…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Add Screenshots…"].exists)
        XCTAssertTrue(app.menuItems["Delete All iPhone 6.9″ Screenshots in German…"].exists)
        app.menuItems["Import a Folder…"].click()
        XCTAssertTrue(element("screenshots.hand.importSheet").waitForExistence(timeout: 5))
        XCTAssertTrue(element("screenshots.hand.import.choose").exists)
        XCTAssertFalse(element("screenshots.hand.sheet.ok").isEnabled, "Nothing to import before a folder")
    }

    func testALanguageWithoutItsOwnUsesThePrimarys() {
        app.launch(debugScene: "hand-fallback")
        let banner = element("screenshots.hand.fallback")
        XCTAssertTrue(banner.waitForExistence(timeout: 20))
        XCTAssertTrue(element("screenshots.hand.startFromPrimary").exists)
        XCTAssertTrue(element("screenshots.hand.addOwn").exists)
        attachScreenshot("Uses English (U.S.)")
    }

    func testAcceptingAnAssistantsFile() {
        app.launch(debugScene: "hand-proposal")
        let accept = element("screenshots.hand.proposal.accept")
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        attachScreenshot("Claude Code's file")
        accept.click()
        XCTAssertTrue(waitUntil { !accept.exists })
        let shot = element("screenshots.page.shot.2")
        XCTAssertTrue(waitUntil { self.text(of: shot).contains("Replaced") }, text(of: shot))
    }

    func testAcceptingASuggestedRemoval() {
        app.launch(debugScene: "hand-removal")
        let title = element("screenshots.hand.arrangement.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: title).contains("Delete screenshots 2 and 4"), text(of: title))
        attachScreenshot("Claude Code suggests deleting 2 and 4")
        let accept = element("screenshots.hand.arrangement.accept")
        accept.click()
        XCTAssertTrue(waitUntil { !accept.exists })
        let shot = element("screenshots.page.shot.1")
        XCTAssertTrue(waitUntil { self.text(of: shot).contains("Will be deleted") }, text(of: shot))
    }

    func testDismissingASuggestedOrderKeepsTheSet() {
        app.launch(debugScene: "hand-order")
        let title = element("screenshots.hand.arrangement.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: title).contains("New order: 3, 1, 2, 4, 5"), text(of: title))
        let first = text(of: element("screenshots.page.shot.0"))
        let dismiss = element("screenshots.hand.arrangement.dismiss")
        dismiss.click()
        XCTAssertTrue(waitUntil { !dismiss.exists })
        XCTAssertEqual(text(of: element("screenshots.page.shot.0")), first)
    }

    func testAcceptingASuggestedOrder() {
        app.launch(debugScene: "hand-order")
        let accept = element("screenshots.hand.arrangement.accept")
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        accept.click()
        XCTAssertTrue(waitUntil { !accept.exists })
        let toast = element("toast.text")
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: toast).contains("Claude Code’s order"), "The toast says the set is in Claude Code's order: \(text(of: toast))")
        attachScreenshot("Claude Code's order accepted")
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
