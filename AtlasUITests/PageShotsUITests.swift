//
//  PageShotsUITests.swift
//  AtlasUITests
//

import XCTest

/// Make Screenshots for This Page (board 52) on Lumen Journal's Private
/// diary, in its DEBUG scenes (Claude Code never starts and nothing reaches
/// Apple): Plan with the angle, the order and the languages; Making under
/// way and hidden, shown again from the page; Result with its checks, and
/// Use These Screenshots putting the set in Review & Push, where the
/// editor shows it as the page's own.
@MainActor
final class PageShotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheEditorOffersMakeScreenshotsForThisPage() {
        app.launch(debugScene: "cp-edit")
        let make = element("pages.screenshots.make")
        XCTAssertTrue(make.waitForExistence(timeout: 15))
        XCTAssertTrue(make.isEnabled)
        attach("cp-edit-make")
    }

    func testPlanningWaitsForClaudeCode() {
        app.launch(debugScene: "cp-shots-planning")
        XCTAssertTrue(element("pages.shots.sheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.planning").waitForExistence(timeout: 10))
        XCTAssertFalse(element("pages.shots.start").isEnabled)
        attach("cp-shots-planning")
    }

    func testThePlanShowsTheAngleTheOrderAndTheLanguagesThenAutopilotMakesTheSet() {
        app.launch(debugScene: "cp-shots-plan")
        XCTAssertTrue(element("pages.shots.sheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.angle").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pages.shots.order.1").exists)
        XCTAssertTrue(text(of: element("pages.shots.order.1")).contains("Privacy"), text(of: element("pages.shots.order.1")))
        XCTAssertTrue(element("pages.shots.look.same").exists)
        XCTAssertTrue(element("pages.shots.language.ar-SA").exists)
        XCTAssertTrue(text(of: element("pages.shots.summary")).contains("default page’s screenshots don’t change"))
        attach("cp-shots-plan")
        let start = element("pages.shots.start")
        XCTAssertTrue(start.isEnabled)
        start.click()
        XCTAssertTrue(element("pages.shots.result.new").waitForExistence(timeout: 60))
        XCTAssertTrue(element("pages.shots.check.default").exists)
    }

    func testHidingKeepsAutopilotGoingAndThePageShowsIt() {
        app.launch(debugScene: "cp-shots-run")
        let progress = element("pages.shots.progressText")
        XCTAssertTrue(progress.waitForExistence(timeout: 20))
        XCTAssertTrue(waitFor(progress, toContain: "2 of"), text(of: progress))
        attach("cp-shots-run")
        element("pages.shots.hide").click()
        XCTAssertTrue(waitForGone(element("pages.shots.sheet")))
        let row = element("pages.screenshots.run.text")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: row).contains("making"), text(of: row))
        attach("cp-shots-run-hidden")
        element("pages.screenshots.run.show").click()
        XCTAssertTrue(element("pages.shots.sheet").waitForExistence(timeout: 10))
    }

    func testUseTheseScreenshotsPutsTheSetInReviewAndPush() {
        app.launch(debugScene: "cp-shots-result")
        let use = element("pages.shots.use")
        XCTAssertTrue(use.waitForExistence(timeout: 60))
        XCTAssertTrue(element("pages.shots.result.new").waitForExistence(timeout: 30))
        XCTAssertTrue(element("pages.shots.check.fit").exists)
        XCTAssertTrue(element("pages.shots.check.rtl").exists)
        XCTAssertTrue(element("pages.shots.use.ar-SA").exists)
        attach("cp-shots-result")
        use.click()
        XCTAssertTrue(waitForGone(element("pages.shots.sheet")))
        XCTAssertTrue(element("pages.screenshots.queued").waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: element("pages.screenshots.note")).contains("Review & Push"), text(of: element("pages.screenshots.note")))
    }

    func testTheQueuedSetShowsAsThePagesOwn() {
        app.launch(debugScene: "cp-shots-queued")
        XCTAssertTrue(element("pages.screenshots.queued").waitForExistence(timeout: 60))
        XCTAssertTrue(text(of: element("pages.screenshots.note")).contains("for this page, in"))
        XCTAssertFalse(element("pages.shots.sheet").exists)
        attach("cp-shots-queued")
    }

    func testThePlanFitsASmallWindow() {
        app.launch(debugScene: "cp-shots-plan-s")
        XCTAssertTrue(element("pages.shots.sheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.start").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pages.shots.start").isHittable)
        XCTAssertTrue(element("pages.shots.cancel").isHittable)
        attach("cp-shots-plan-s")
    }

    func testWithoutTheDefaultPagesScreenshotsItSaysSoAndOpensScreenshots() {
        app.launch(debugScene: "cp-shots-none")
        let make = element("pages.screenshots.make")
        XCTAssertTrue(make.waitForExistence(timeout: 15))
        make.click()
        let problem = element("pages.shots.problem")
        XCTAssertTrue(problem.waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: problem).contains("no screenshots made in Atlas yet"), text(of: problem))
        attach("cp-shots-none")
        element("pages.shots.openScreenshots").click()
        XCTAssertTrue(waitForGone(element("pages.shots.sheet")))
        XCTAssertTrue(element("workspace.screenshots").waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitFor(_ element: XCUIElement, toContain text: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if self.text(of: element).contains(text) { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return false
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if !element.exists { return true }
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
