//
//  ReviewRisksUITests.swift
//  AtlasUITests
//

import XCTest

/// The Overview's App Review card in its DEBUG scenes (sample risks,
/// nothing reaches Apple): rows most serious first with their level,
/// Dismiss, Check Now before the first check, and the clear state.
@MainActor
final class ReviewRisksUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testRisksShowMostSeriousFirstAndDismissHidesOne() {
        app.launch(debugScene: "rr-card")
        let title = element("overview.reviewRisks.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: title).contains("4 things App Review may reject"), text(of: title))
        let terms = element("overview.reviewRisks.row.subscriptionTerms:app")
        XCTAssertTrue(terms.exists)
        XCTAssertTrue(terms.label.contains("Blocks review"), terms.label)
        XCTAssertTrue(text(of: element("overview.reviewRisks.footer")).contains("1 check couldn’t run"))
        attach("rr-card")
        element("overview.reviewRisks.dismiss.subscriptionTerms:app").click()
        XCTAssertTrue(waitForGone(element("overview.reviewRisks.row.subscriptionTerms:app")))
        XCTAssertTrue(text(of: title).contains("3 things"), text(of: title))
    }

    func testNeverCheckedOffersCheckNow() {
        app.launch(debugScene: "rr-empty")
        let check = element("overview.reviewRisks.check")
        XCTAssertTrue(check.waitForExistence(timeout: 15))
        XCTAssertEqual(check.label, "Check Now")
        attach("rr-empty")
        check.click()
        XCTAssertTrue(element("overview.reviewRisks.row.whatsNew:de-DE").waitForExistence(timeout: 5))
        XCTAssertEqual(element("overview.reviewRisks.check").label, "Check Again")
    }

    func testNothingFoundSaysSo() {
        app.launch(debugScene: "rr-clear")
        let title = element("overview.reviewRisks.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: title).contains("Nothing App Review is likely to reject"), text(of: title))
        attach("rr-clear")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
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
