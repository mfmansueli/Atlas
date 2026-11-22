//
//  AutopilotButtonAnimationUITests.swift
//  AtlasUITests
//

import XCTest

/// The Autopilot button while it works (board 57, “While it works”), on
/// `AutopilotButtonDebugScenes` and a real request (`cc-ask`): every look
/// drawn, a run that ends by itself shows Done and goes back to idle, and
/// the toolbar's button is the hand-built split, its label what runs.
@MainActor
final class AutopilotButtonAnimationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testEveryLookIsDrawn() {
        app.launch(debugScene: "ap-btn")
        XCTAssertTrue(element("apButton.gallery").waitForExistence(timeout: 20))
        let mains = app.descendants(matching: .any).matching(identifier: "workspace.autopilot.main")
        XCTAssertEqual(mains.count, 7)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "workspace.autopilot.more").count, 7)
        attachScreenshot("Every look")
    }

    func testARunThatEndsShowsDoneThenGoesIdle() {
        app.launch(debugScene: "ap-btn-cycle")
        let main = element("workspace.autopilot.main")
        XCTAssertTrue(main.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 12) { self.text(of: main).hasPrefix("Making screenshots") }, text(of: main))
        attachScreenshot("Working")
        XCTAssertTrue(waitUntil(timeout: 12) { self.text(of: main) == "Done · Store Page · German" }, text(of: main))
        attachScreenshot("Done")
        XCTAssertTrue(waitUntil(timeout: 5) { self.text(of: main) == "Suggest Texts" }, "Back to idle after about 2 s: \(text(of: main))")
    }

    func testTheToolbarButtonSaysWhatRuns() {
        app.launch(debugScene: "cc-ask")
        let autopilot = element("workspace.autopilot")
        XCTAssertTrue(autopilot.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 10) { autopilot.label == "Autopilot, Claude Code is working on Store Page" }, autopilot.label)
        XCTAssertTrue(element("workspace.autopilot.main").exists)
        XCTAssertTrue(element("workspace.autopilot.more").exists)
        attachScreenshot("Toolbar · working")
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
