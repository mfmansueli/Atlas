//
//  ProductPagePushAndFilesUITests.swift
//  AtlasUITests
//

import XCTest

/// Custom Product Pages in DEBUG scenes (Lumen Journal's sample pages;
/// nothing reaches Apple): Push and Submit… opens Review & Push on the
/// page's own changes (board 54), and Choose Files… takes screenshots the
/// person has, checked against Apple's sizes (board 52).
@MainActor
final class ProductPagePushAndFilesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testPushAndSubmitOpensReviewAndPushOnThePage() {
        app.launch(debugScene: "cp-edit")
        let submit = element("pages.editor.submit")
        XCTAssertTrue(submit.waitForExistence(timeout: 15))
        submit.click()
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 10))
        let scope = element("review.scope")
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        let page = scope.radioButtons.matching(NSPredicate(format: "label BEGINSWITH %@", "Private diary")).firstMatch
        XCTAssertTrue(page.exists, scope.debugDescription)
        XCTAssertTrue(page.isSelected || (page.value as? Int) == 1 || (page.value as? String) == "1", page.debugDescription)
        attach("cp-review-page")
        let thisApp = scope.radioButtons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lumen Journal")).firstMatch
        XCTAssertTrue(thisApp.exists)
        thisApp.click()
        XCTAssertTrue(waitUntil { thisApp.isSelected || (thisApp.value as? Int) == 1 })
    }

    /// The board's page push sheet (cp-push…) is Review & Push on the page:
    /// ready with the switch to the app's changes, and pushing the page.
    func testThePushScenesOpenReviewAndPushOnThePage() {
        app.launch(debugScene: "cp-push")
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 15))
        let scope = element("review.scope")
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        let page = scope.radioButtons.matching(NSPredicate(format: "label BEGINSWITH %@", "Private diary")).firstMatch
        XCTAssertTrue(page.exists, scope.debugDescription)
        attach("cp-push")
        app.terminate()

        app.launch(debugScene: "cp-push-partial")
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 15))
        let failed = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "didn’t go in", "didn’t go in")).firstMatch
        XCTAssertTrue(failed.waitForExistence(timeout: 15))
        attach("cp-push-partial")
    }

    func testChosenScreenshotsWaitInReviewAndPush() {
        app.launch(debugScene: "cp-files")
        let queued = element("pages.screenshots.queued")
        scrollTo(queued)
        XCTAssertTrue(queued.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: element("pages.screenshots.note")).contains("2 screenshots"), text(of: element("pages.screenshots.note")))
        XCTAssertTrue(element("pages.screenshots.chooseFiles").exists)
        XCTAssertTrue(element("pages.screenshots.chooseVideos").exists)
        attach("cp-files")
    }

    func testAWrongSizeIsRefusedWithTheSizesThatWork() {
        app.launch(debugScene: "cp-files-wrong")
        let okButton = element("pages.filesProblem.ok")
        XCTAssertTrue(okButton.waitForExistence(timeout: 15))
        let message = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "1170 × 2532", "1170 × 2532")).firstMatch
        XCTAssertTrue(message.exists)
        attach("cp-files-wrong")
        okButton.click()
        XCTAssertTrue(waitUntil { !okButton.exists })
        XCTAssertFalse(element("pages.screenshots.queued").exists)
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The editor scrolls: what's below the fold comes up.
    private func scrollTo(_ target: XCUIElement) {
        _ = element("pages.editor.scroll").waitForExistence(timeout: 15)
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            element("pages.editor.scroll").scroll(byDeltaX: 0, deltaY: -400)
        }
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
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
