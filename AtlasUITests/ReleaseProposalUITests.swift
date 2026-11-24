//
//  ReleaseProposalUITests.swift
//  AtlasUITests
//

import XCTest

/// An assistant's release proposal on the Overview's version card, in
/// the `rel-proposed-*` DEBUG scenes (Lumen Journal 1.4, nothing reaches
/// Apple): who and why, Confirm running the card's own action (asking
/// first where it asks), Submit's choices in the sheet, Dismiss, and one
/// that no longer fits.
@MainActor
final class ReleaseProposalUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAProposedReleaseAsksFirstAndThenReleases() {
        app.launch(debugScene: "rel-proposed-release")
        let banner = element("overview.version.proposal")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.proposal.title")), "Release 1.4 now")
        XCTAssertTrue(text(of: element("overview.version.proposal.reason")).contains("Mood Calendar event starts on Friday"))
        let confirm = element("overview.version.proposal.confirm")
        XCTAssertEqual(confirm.label, "Release 1.4 Now…")
        attach("rel-proposed-release")

        confirm.click()
        let asked = element("overview.version.confirm")
        XCTAssertTrue(asked.waitForExistence(timeout: 5), "The card's own question comes first")
        asked.click()
        XCTAssertTrue(element("overview.version.phased").waitForExistence(timeout: 10))
        XCTAssertTrue(banner.waitForNonExistence(timeout: 10), "Done: the proposal is settled")
    }

    /// A waiting proposal counts on the Overview in the sidebar, and the
    /// count goes once it's dismissed.
    func testAWaitingProposalCountsOnTheOverview() {
        app.launch(debugScene: "rel-proposed-release")
        XCTAssertTrue(element("overview.version.proposal").waitForExistence(timeout: 15))
        let overview = element("sidebar.section.overview")
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
        XCTAssertTrue(overview.label.contains("1 suggestion to review"), overview.label)
        element("overview.version.proposal.dismiss").click()
        XCTAssertTrue(element("overview.version.proposal").waitForNonExistence(timeout: 5))
        let deadline = Date.now.addingTimeInterval(5)
        while overview.label.contains("suggestion to review"), Date.now < deadline {
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        XCTAssertFalse(overview.label.contains("suggestion to review"), overview.label)
    }

    func testDismissLeavesTheVersionAsItIs() {
        app.launch(debugScene: "rel-proposed-release")
        XCTAssertTrue(element("overview.version.proposal").waitForExistence(timeout: 15))
        element("overview.version.proposal.dismiss").click()
        XCTAssertTrue(element("overview.version.proposal").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("overview.version.release").exists, "Release Now is still the person's")
        XCTAssertEqual(text(of: element("overview.version.pill")), "Pending Developer Release")
    }

    func testAProposedPauseRunsThePauseButton() {
        app.launch(debugScene: "rel-proposed-pause")
        let confirm = element("overview.version.proposal.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.proposal.title")), "Pause the phased release of 1.4")
        XCTAssertTrue(element("overview.version.proposal.evidence").exists)
        attach("rel-proposed-pause")
        confirm.click()
        let paused = NSPredicate(format: "label == %@ OR value == %@", "Phased Release paused", "Phased Release paused")
        let pill = element("overview.version.pill")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: paused, object: pill)], timeout: 10), .completed, text(of: pill))
        XCTAssertTrue(element("overview.version.proposal").waitForNonExistence(timeout: 5))
    }

    func testAProposedSubmissionOpensTheSheetWithItsChoices() {
        app.launch(debugScene: "rel-proposed-submit")
        XCTAssertTrue(element("overview.version.proposal").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.proposal.title")), "Submit 1.4 for App Review")
        let choices = text(of: element("overview.version.proposal.choices"))
        XCTAssertTrue(choices.contains("Build 1.4 (211)"), choices)
        XCTAssertTrue(choices.contains("With “Mood Calendar”"), choices)
        let confirm = element("overview.version.proposal.confirm")
        XCTAssertEqual(confirm.label, "Review in Submit…")
        attach("rel-proposed-submit")

        confirm.click()
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 10))
        XCTAssertTrue(element("submit.build.211").isSelected, "The proposed build is chosen")
        XCTAssertTrue(element("submit.timing.afterApproval").isSelected)
        XCTAssertFalse(element("submit.submit").isEnabled, "Italian What’s New still waits for the person")
        attach("rel-proposed-submit-sheet")
    }

    func testAProposalThatNoLongerFitsCanOnlyBeDismissed() {
        app.launch(debugScene: "rel-proposed-outdated")
        XCTAssertTrue(element("overview.version.proposal").waitForExistence(timeout: 15))
        XCTAssertTrue(element("overview.version.proposal.outdated").exists)
        XCTAssertFalse(element("overview.version.proposal.confirm").exists)
        attach("rel-proposed-outdated")
        element("overview.version.proposal.dismiss").click()
        XCTAssertTrue(element("overview.version.proposal").waitForNonExistence(timeout: 5))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Waiting for Review")
    }

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
