//
//  ProductPageTestProposalUITests.swift
//  AtlasUITests
//

import XCTest

/// A Product Page Optimization test Claude Code proposed over MCP
/// (`propose_page_test`), in Review & Push: its card with why, the sheet
/// opened prefilled from it, and Dismiss. Driven through the DEBUG scenes
/// `shots-ppo-proposed` and `shots-ppo-proposed-sheet`: a simulated App
/// Store Connect, so nothing leaves the Mac.
@MainActor
final class ProductPageTestProposalUITests: XCTestCase {
    private var app: XCUIApplication!
    private let proposalID = "pt-debug01"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// The card says who proposed what and why; Review Test… opens the
    /// sheet filled in with it.
    func testTheProposedTestWaitsOnItsCard() {
        app.launch(debugScene: "shots-ppo-proposed")
        let card = element("review.extras.testProposal.\(proposalID)")
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(text(of: element("review.extras.testProposal.name")).contains("Header: Editor vs Calm morning"))
        let reason = text(of: element("review.extras.testProposal.reason"))
        XCTAssertTrue(reason.contains("Claude Code"), reason)
        XCTAssertTrue(reason.contains("a calmer header"), reason)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "30% of visitors", "30% of visitors"))
            .firstMatch.exists)

        let open = app.buttons["review.extras.testProposal.open"]
        XCTAssertTrue(open.exists)
        open.click()
        XCTAssertTrue(element("ppo.sheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("ppo.proposal").exists)
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = "Proposed test"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Opened on the proposal: its reason, name and traffic, the review
    /// choice off, and Create Test ready since the variant is in.
    func testTheSheetOpensFilledInFromTheProposal() {
        app.launch(debugScene: "shots-ppo-proposed-sheet")
        XCTAssertTrue(element("ppo.sheet").waitForExistence(timeout: 30))
        XCTAssertTrue(element("ppo.proposal").exists)
        XCTAssertTrue(text(of: element("ppo.proposal.reason")).contains("a calmer header"))
        let summary = text(of: element("ppo.proposal.summary"))
        XCTAssertTrue(summary.contains("Header: Editor vs Calm morning"), summary)
        XCTAssertTrue(summary.contains("30% of visitors see the treatment"), summary)
        let starts = app.checkBoxes["ppo.startsTest"]
        XCTAssertTrue(starts.exists)
        XCTAssertEqual(starts.value as? Int, 0, "It stays a draft unless the person sends it to review")
        let create = app.buttons["ppo.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertTrue(create.isEnabled)
    }

    /// Dismiss takes the card away; nothing reaches App Store Connect.
    func testDismissTakesTheCardAway() {
        app.launch(debugScene: "shots-ppo-proposed")
        let card = element("review.extras.testProposal.\(proposalID)")
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        app.buttons["review.extras.testProposal.dismiss"].click()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: card)
        wait(for: [gone], timeout: 15)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The label and the value, whichever it has (a text's is its value).
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
