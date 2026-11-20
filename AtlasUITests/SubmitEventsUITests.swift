//
//  SubmitEventsUITests.swift
//  AtlasUITests
//

import XCTest

/// The Submit sheet's In-App Events in their DEBUG scenes (Lumen Journal
/// 1.4 with its Mood Calendar event ticked, nothing reaches Apple): an
/// event App Store Connect would refuse blocks Submit until it's fixed or
/// unticked, and the deep link check's warnings.
@MainActor
final class SubmitEventsUITests: XCTestCase {
    private var app: XCUIApplication!
    private let mood = "event-mood"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Alba 1.2.0: three events without a deep link made App Store Connect
    /// refuse the whole submission.
    func testAnEventWithoutADeepLinkBlocksSubmitUntilUnticked() {
        app.launch(debugScene: "rel-sheet-ev-missing")
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 20))
        let missing = element("submit.event.\(mood).missing.deepLink")
        XCTAssertTrue(missing.waitForExistence(timeout: 10))
        XCTAssertTrue(element("submit.event.\(mood).fix").exists)
        XCTAssertEqual(text(of: element("submit.footer")), "To submit, fix or untick “Mood Calendar”.")
        XCTAssertFalse(element("submit.submit").isEnabled)
        attach("rel-sheet-ev-missing")

        element("submit.event.\(mood)").click()
        XCTAssertTrue(missing.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("submit.submit").isEnabled)
    }

    func testFixOpensTheEventsPage() {
        app.launch(debugScene: "rel-sheet-ev-missing")
        let fix = element("submit.event.\(mood).fix")
        XCTAssertTrue(fix.waitForExistence(timeout: 20))
        fix.click()
        XCTAssertTrue(element("submit.sheet").waitForNonExistence(timeout: 10))
        XCTAssertTrue(element("events.details").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.review.deepLink").exists)
    }

    func testALinkTheProjectDoesntClaimBlocksWithMakeItWork() {
        app.launch(debugScene: "rel-sheet-ev-unclaimed")
        XCTAssertTrue(element("submit.event.\(mood).missing.linkNotClaimed").waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Lumen Journal doesn’t open lumen:// links yet"].exists)
        XCTAssertTrue(element("submit.event.\(mood).makeItWork").exists)
        XCTAssertFalse(element("submit.submit").isEnabled)
        attach("rel-sheet-ev-unclaimed")
    }

    func testALinkNobodyCheckedIsACalmNote() {
        app.launch(debugScene: "rel-sheet-ev-unchecked")
        let note = element("submit.event.\(mood).note")
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: note).hasPrefix("Not checked: nobody has tried its deep link in Lumen Journal’s code yet."))
        XCTAssertTrue(element("submit.event.\(mood).check").exists)
        XCTAssertTrue(element("submit.submit").isEnabled, "Not checked isn’t a block")
        attach("rel-sheet-ev-unchecked")
    }

    func testAnOlderBuildThanTheCheckedOneWarnsAndOffersIt() {
        app.launch(debugScene: "rel-sheet-ev-older")
        let warning = element("submit.event.\(mood).warning")
        XCTAssertTrue(warning.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: warning), "Build 211 is older than the build where Lumen Journal opens these links (212).")
        attach("rel-sheet-ev-older")
        element("submit.event.\(mood).useBuild").click()
        XCTAssertTrue(warning.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("submit.submit").isEnabled)
    }

    func testACheckThatFailedWarnsButLetsItGo() {
        app.launch(debugScene: "rel-sheet-ev-fails")
        let warning = element("submit.event.\(mood).warning")
        XCTAssertTrue(warning.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: warning).hasPrefix("Claude Code found that Lumen Journal doesn’t open its deep link yet."))
        XCTAssertTrue(element("submit.event.\(mood).makeItWork").exists)
        XCTAssertTrue(element("submit.submit").isEnabled)
        attach("rel-sheet-ev-fails")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
