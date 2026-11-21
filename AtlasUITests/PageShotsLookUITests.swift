//
//  PageShotsLookUITests.swift
//  AtlasUITests
//

import XCTest

/// Board 52's Look and Capture Screens Again on Lumen Journal's Private
/// diary, in DEBUG scenes (Claude Code never starts and nothing reaches
/// Apple): another template shows its picker, a new look from Claude
/// Design is a stop where the person chooses one of three, and a screen
/// captured again goes back to the default page's capture.
@MainActor
final class PageShotsLookUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAnotherTemplateOffersAtlassTemplates() {
        app.launch(debugScene: "cp-shots-plan")
        let other = element("pages.shots.look.template")
        XCTAssertTrue(other.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.look.same").isSelected)
        XCTAssertFalse(element("pages.shots.look.templatePicker").exists)
        scrollPlanToEnd()
        other.click()
        XCTAssertTrue(element("pages.shots.look.templatePicker").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pages.shots.look.template").isSelected)
        XCTAssertTrue(element("pages.shots.start").isEnabled)
        attach("cp-shots-template")
    }

    func testANewLookIsAStopWhereThePersonChoosesOneOfThree() {
        app.launch(debugScene: "cp-shots-looks")
        let looks = element("pages.shots.looks")
        XCTAssertTrue(looks.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.look.claudeDesign").isSelected)
        scrollPlanToEnd()
        let chosen = element("pages.shots.looks.Paper Lock")
        let other = element("pages.shots.looks.Night Mode")
        XCTAssertTrue(chosen.waitForExistence(timeout: 10))
        XCTAssertTrue(chosen.isSelected)
        XCTAssertTrue(element("pages.shots.looks.Quiet Indigo").exists)
        attach("cp-shots-looks")
        other.click()
        XCTAssertTrue(waitFor { other.isSelected && !chosen.isSelected })
        XCTAssertTrue(element("pages.shots.start").isEnabled)
    }

    func testWhileClaudeDesignDrawsTheSheetSaysHowManyAreReady() {
        app.launch(debugScene: "cp-shots-looks-drawing")
        let drawing = element("pages.shots.looks.drawing")
        XCTAssertTrue(drawing.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: drawing).contains("1 of 3"), text(of: drawing))
        attach("cp-shots-looks-drawing")
    }

    func testAScreenCapturedAgainCanGoBackToTheDefault() {
        app.launch(debugScene: "cp-shots-looks")
        let screen = element("pages.shots.captures.screen.5")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.shots.recapture").exists)
        XCTAssertTrue(text(of: element("pages.shots.order.1")).contains("captured again"), text(of: element("pages.shots.order.1")))
        element("pages.shots.captures.default.5").click()
        XCTAssertTrue(waitFor { !screen.exists })
        XCTAssertFalse(text(of: element("pages.shots.order.1")).contains("captured again"))
    }

    // MARK: - Helpers

    private func scrollPlanToEnd() {
        let scroll = element("pages.shots.planScroll")
        guard scroll.exists else { return }
        scroll.scroll(byDeltaX: 0, deltaY: -2000)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitFor(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
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
