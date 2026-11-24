//
//  NominationsUITests.swift
//  AtlasUITests
//

import XCTest

/// Featuring Nominations (⇧⌘F) in its DEBUG scenes (board 70; Lumen
/// Journal's sample nominations, nothing reaches Apple): a new nomination
/// written and added to Review & Push, and Submit only after its
/// confirmation.
@MainActor
final class NominationsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testANewNominationGoesToReviewAndPush() {
        app.launch(debugScene: "ft-gallery")
        XCTAssertTrue(element("nominations.gallery").waitForExistence(timeout: 15))
        XCTAssertTrue(element("nominations.group.draft").exists)
        XCTAssertTrue(element("nominations.group.submitted").exists)
        attach("ft-gallery")
        element("nominations.new").click()
        XCTAssertTrue(element("nominations.page").waitForExistence(timeout: 10))
        // Not ready yet: Add to Review & Push waits for the fields.
        XCTAssertFalse(element("nominations.page.add").isEnabled)
        element("nominations.type.APP_ENHANCEMENTS").click()
        let name = element("nominations.name")
        name.click()
        name.typeText("Lumen 1.5: Shared journals")
        let description = element("nominations.description")
        description.click()
        description.typeText("Write a journal with someone you trust, each page private until you share it.")
        scrollTo(element("nominations.dates.choose"))
        element("nominations.dates.choose").click()
        XCTAssertTrue(element("nominations.dates.start").waitForExistence(timeout: 5))
        let add = element("nominations.page.add")
        XCTAssertTrue(waitUntil { add.isEnabled })
        add.click()
        XCTAssertTrue(element("nominations.page.openReview").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In Review & Push. Nothing is sent until you push."].waitForExistence(timeout: 5))
        attach("ft-new-added")
    }

    func testSubmitWaitsForItsConfirmation() {
        app.launch(debugScene: "ft-edit")
        let submit = element("nominations.page.submit")
        XCTAssertTrue(submit.waitForExistence(timeout: 15))
        submit.click()
        let sheet = element("nominations.sheet.submit")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: element("nominations.sheet.title")).contains("Submit to Apple’s Editors"))
        attach("ft-submit")
        // Cancel queues nothing.
        element("nominations.sheet.cancel").click()
        XCTAssertTrue(waitUntil { !sheet.exists })
        XCTAssertFalse(element("nominations.page.cancelSubmit").exists)
        submit.click()
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        element("nominations.sheet.confirm").click()
        XCTAssertTrue(element("nominations.page.cancelSubmit").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Submit is in Review & Push. Nothing is sent until you push."].waitForExistence(timeout: 5))
        attach("ft-submit-queued")
    }

    func testASubmittedNominationIsReadOnlyAndArchivesAfterItsConfirmation() {
        app.launch(debugScene: "ft-submitted")
        XCTAssertTrue(element("nominations.readOnly").waitForExistence(timeout: 15))
        XCTAssertFalse(element("nominations.page.submit").exists)
        element("nominations.page.archive").click()
        XCTAssertTrue(element("nominations.sheet.archive").waitForExistence(timeout: 5))
        element("nominations.sheet.confirm").click()
        XCTAssertTrue(element("nominations.page.cancelArchive").waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The page scrolls: what's below the fold comes up.
    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            element("nominations.page").scroll(byDeltaX: 0, deltaY: -300)
        }
    }

    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
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
