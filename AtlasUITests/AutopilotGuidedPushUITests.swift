//
//  AutopilotGuidedPushUITests.swift
//  AtlasUITests
//

import XCTest

/// The guided Autopilot's last steps, on `StudioDebugGuided`'s scenes:
/// Review & approve (Approve All, which puts the set in Review & Push) and
/// Done, which only follows the push Review & Push makes. Each test
/// attaches the window's screenshot.
@MainActor
final class AutopilotGuidedPushUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Approve All (board 57) is the last step: it approves what's left
    /// itself, so it's on before every part is.
    func testApproveAllIsTheLastStep() {
        app.launch(debugScene: "ap-review")
        let approve = element("autopilot.guided.review.approve")
        XCTAssertTrue(approve.waitForExistence(timeout: 20))
        let approveAll = element("autopilot.guided.approveAll")
        XCTAssertTrue(approveAll.exists)
        XCTAssertEqual(approveAll.label, "Approve All")
        XCTAssertFalse(element("autopilot.guided.push").exists, "No push from the sheet")
        attachScreenshot("Review · screenshots")
    }

    /// Approve All waits for a caption proposal to be decided; one that
    /// then finds nothing to put in Review & Push (this scene has no App
    /// Store Connect) keeps Autopilot open and says why.
    func testApproveAllWithNothingToPushStaysInAutopilot() {
        app.launch(debugScene: "ap-review")
        let approveAll = element("autopilot.guided.approveAll")
        XCTAssertTrue(approveAll.waitForExistence(timeout: 20))
        // A caption proposal waits in the checks: Approve All waits for it.
        XCTAssertFalse(approveAll.isEnabled, "Shorter German captions wait for a decision")
        let reject = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "autopilot.guided.review.check.", ".reject"))
            .firstMatch
        XCTAssertTrue(reject.waitForExistence(timeout: 10))
        reject.click()
        XCTAssertTrue(waitUntil(timeout: 30) { approveAll.isEnabled })
        approveAll.click()
        XCTAssertTrue(app.staticTexts["Couldn’t add it to Review & Push. Try again."].waitForExistence(timeout: 10))
        XCTAssertTrue(element("autopilot.guided.sheet").exists)
        XCTAssertFalse(element("review.sheet").exists)
        attachScreenshot("Review · nothing to push")
    }

    func testTheHeaderTabFollowsTheApprovedScreenshots() {
        app.launch(debugScene: "ap-review-art")
        let approve = element("autopilot.guided.review.approve")
        XCTAssertTrue(approve.waitForExistence(timeout: 20))
        XCTAssertEqual(approve.label, "Approve Header and Search")
        attachScreenshot("Review · header and search")
    }

    /// After Approve All, Done says the set waits in Review & Push and
    /// opens it: no push, progress or Try Again of its own.
    func testDoneAfterApproveAllWaitsInReviewAndPush() {
        app.launch(debugScene: "ap-done")
        let title = element("autopilot.guided.done.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: title), "Waiting in Review & Push")
        XCTAssertTrue(text(of: element("autopilot.guided.done.text")).contains("Push it from there"))
        let open = element("autopilot.guided.done.openReview")
        XCTAssertTrue(open.exists)
        XCTAssertEqual(open.label, "Open Review & Push…")
        XCTAssertFalse(element("autopilot.guided.done.retry").exists, "Try Again is Review & Push's")
        XCTAssertFalse(element("autopilot.guided.done.images").exists, "The push's progress is Review & Push's")
        XCTAssertFalse(element("autopilot.guided.done.extras").exists)
        XCTAssertFalse(element("autopilot.guided.approveAll").exists, "No footer once it's approved")
        XCTAssertFalse(element("autopilot.guided.push").exists, "No push from the sheet")
        attachScreenshot("Done · waiting in Review & Push")
    }

    /// A run pushed from the sheet before board 57, after a relaunch: Done
    /// can't tell how it ended, and says so.
    func testDoneAfterARelaunchSaysItCantTell() {
        app.launch(debugScene: "ap-done-sent")
        let title = element("autopilot.guided.done.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: title), "Sent from this Mac")
        XCTAssertTrue(text(of: element("autopilot.guided.done.text")).contains("can’t tell how it ended"))
        XCTAssertFalse(element("autopilot.guided.approveAll").exists, "No footer once it's sent")
        attachScreenshot("Sent")
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
