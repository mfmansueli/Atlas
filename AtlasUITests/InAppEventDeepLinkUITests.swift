//
//  InAppEventDeepLinkUITests.swift
//  AtlasUITests
//

import XCTest

/// An event page's details and deep link in their DEBUG scenes (Lumen
/// Journal's sample events, nothing reaches Apple): "Before App Review"
/// with its fixes, the deep link edited and checked, an assistant's deep
/// link accepted, and what Atlas reads in the project folder.
@MainActor
final class InAppEventDeepLinkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Alba 1.2.0's events had no deep link: the page lists it first, and
    /// Add Deep Link goes to the field, which checks it like App Store
    /// Connect and queues it.
    func testADraftWithoutADeepLinkSaysSoAndTakesOne() {
        app.launch(debugScene: "ev-link-none")
        let item = element("events.review.deepLink")
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["No deep link: Open on the card has nowhere to go."].exists)
        attach("ev-link-none")

        element("events.review.deepLink.fix").click()
        let field = element("events.details.deepLink")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("lumen challenge")
        XCTAssertTrue(element("events.details.deepLink.problem").waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: element("events.details.deepLink.problem")).hasPrefix("The deep link isn’t a valid URL."))

        field.typeKey("a", modifierFlags: .command)
        field.typeText("lumen://challenges/winter-2026\r")
        XCTAssertTrue(element("events.details.deepLink.pending").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Waits in Review & Push"].waitForExistence(timeout: 5))
        attach("ev-link-none-queued")

        element("events.details.deepLink.undo").click()
        XCTAssertTrue(element("events.details.deepLink.pending").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.review.deepLink.fix").exists)
    }

    func testAnAssistantsDeepLinkWaitsForAccept() {
        app.launch(debugScene: "ev-link-suggested")
        let accept = element("events.details.deepLink.accept")
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        XCTAssertTrue(element("events.details.purpose.accept").exists)
        XCTAssertTrue(app.staticTexts["Suggested · accept it below"].exists)
        attach("ev-link-suggested")
        accept.click()
        XCTAssertTrue(element("events.details.deepLink.pending").waitForExistence(timeout: 5))
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
    }

    /// Lumen's project declares no lumen:// scheme: the link opens
    /// nothing, so Make It Work… is offered on the list and the details.
    func testALinkTheProjectDoesntClaimOffersMakeItWork() {
        app.launch(debugScene: "ev-link-unclaimed")
        XCTAssertTrue(element("events.review.linkNotClaimed").waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: element("events.deepLink.claim")), "Lumen Journal doesn’t open lumen:// links yet")
        XCTAssertTrue(element("events.review.linkNotClaimed.fix").exists)
        XCTAssertTrue(element("events.deepLink.makeItWork").exists)
        XCTAssertTrue(element("events.deepLink.check").exists)
        attach("ev-link-unclaimed")
    }

    func testAClaimedLinkNobodyCheckedSaysSo() {
        app.launch(debugScene: "ev-link-claimed")
        let status = element("events.deepLink.status")
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: status), "Not checked")
        XCTAssertEqual(
            text(of: element("events.deepLink.claim")), "lumen:// is Lumen Journal’s, but Atlas can’t tell whether it opens this event."
        )
        XCTAssertTrue(element("events.deepLink.check").exists)
        XCTAssertFalse(element("events.review").exists, "Nothing else is missing")
        attach("ev-link-claimed")
    }

    func testACheckThatPassedSaysWhereAndInWhichBuild() {
        app.launch(debugScene: "ev-link-opens")
        let status = element("events.deepLink.status")
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: status), "Opens the event · checked by Claude Code in build 1.4 (212), tried in Simulator")
        XCTAssertTrue(app.staticTexts["Before it starts: The Mood Calendar with “Starts Nov 24” over it"].exists)
        XCTAssertTrue(element("events.deepLink.check").exists)
        XCTAssertFalse(element("events.deepLink.makeItWork").exists)
        attach("ev-link-opens")
    }

    func testACheckThatFailedOffersMakeItWork() {
        app.launch(debugScene: "ev-link-fails")
        let status = element("events.deepLink.status")
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: status), "Doesn’t open it yet")
        XCTAssertTrue(app.staticTexts["LumenApp has no onOpenURL: the link opens the app on its home screen."].exists)
        XCTAssertTrue(element("events.deepLink.makeItWork").exists)
        attach("ev-link-fails")
    }

    func testWithoutAProjectFolderItAsksForOne() {
        app.launch(debugScene: "ev-link-nofolder")
        XCTAssertTrue(element("events.deepLink.chooseFolder").waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: element("events.deepLink.claim")).contains("choose Lumen Journal’s project folder"))
        attach("ev-link-nofolder")
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
