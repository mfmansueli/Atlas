//
//  ExportComplianceKeyUITests.swift
//  AtlasUITests
//

import XCTest

/// Export Compliance's "Skip the question for every build" and the page's
/// wording in their DEBUG scenes (Lumen Journal's sample, no project folder
/// read, nothing reaches Apple, Claude Code never starts): Add It to the
/// Project off until the answers are confirmed, on once they are, a run
/// going, Claude Code's report, its problem with Try Again, inferred from
/// the uploads, and a first version whose build only says exempt.
@MainActor
final class ExportComplianceKeyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Claude Code's answers wait for Confirm: a wrong No in every build is
    /// a false declaration, so the button is off and says why.
    func testAnUnconfirmedSuggestionKeepsAddItOff() {
        app.launch(debugScene: "info-export")
        let button = element("appInformation.export.addKey")
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(element("appInformation.export.addKey.why").exists)
        XCTAssertTrue(text(containing: "Confirm or reject Claude Code’s answers first").exists)
        XCTAssertTrue(element("appInformation.export.copyKey").exists)
        attach("info-export")
    }

    func testConfirmedAnswersTurnAddItOn() {
        app.launch(debugScene: "info-key-ready")
        let button = element("appInformation.export.addKey")
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(element("appInformation.export.addKey.why").exists)
        XCTAssertTrue(text(containing: "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO").exists)
        attach("info-key-ready")
    }

    func testARunGoingSaysSo() {
        app.launch(debugScene: "info-key-running")
        XCTAssertTrue(element("appInformation.export.key.running").waitForExistence(timeout: 20))
        attach("info-key-running")
    }

    func testClaudeCodesReportShowsWhereItWasAdded() {
        app.launch(debugScene: "info-key-added")
        XCTAssertTrue(element("appInformation.export.key.status").waitForExistence(timeout: 20))
        XCTAssertTrue(text(containing: "Added in project.pbxproj (Lumen) · future builds answer it").exists)
        XCTAssertTrue(text(containing: "By Claude Code").exists)
        XCTAssertTrue(text(containing: "commit 4f2a9c1e7b").exists)
        XCTAssertFalse(element("appInformation.export.addKey").exists)
        XCTAssertFalse(element("appInformation.export.copyKey").exists)
        attach("info-key-added")
    }

    func testAProblemOffersTryAgain() {
        app.launch(debugScene: "info-key-failed")
        XCTAssertTrue(element("appInformation.export.key.problem").waitForExistence(timeout: 20))
        XCTAssertTrue(text(containing: "Claude Code couldn’t add it").exists)
        let button = element("appInformation.export.addKey")
        XCTAssertTrue(button.exists)
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(app.buttons["Try Again"].exists || text(containing: "Try Again").exists)
        attach("info-key-failed")
    }

    /// Nobody answered in Atlas, and builds 44, 43 and 42 arrived answered:
    /// done, but marked as inferred, with Check in the Project….
    func testUploadsThatArriveAnsweredAreInferred() {
        app.launch(debugScene: "info-key-inferred")
        XCTAssertTrue(element("appInformation.export.key.status").waitForExistence(timeout: 20))
        XCTAssertTrue(text(containing: "Builds already answer it").exists)
        XCTAssertTrue(text(containing: "Inferred only").exists)
        XCTAssertTrue(app.buttons["Check in the Project…"].exists || text(containing: "Check in the Project…").exists)
        XCTAssertFalse(element("appInformation.export.copyKey").exists)
        attach("info-key-inferred")
    }

    /// Lumen 1.0, never on the App Store, its build only saying exempt: the
    /// bar says the version isn't on the App Store yet, and the answers
    /// read Yes and exempt, marked as the build's.
    func testAFirstVersionsBuildOnlyAnswerReadsAsExempt() {
        app.launch(debugScene: "info-export-first")
        XCTAssertTrue(element("appInformation.exportCompliance").waitForExistence(timeout: 20))
        XCTAssertTrue(text(containing: "Version 1.0 isn’t on the App Store yet.").exists)
        XCTAssertFalse(text(containing: "Not on the App Store.").exists)
        XCTAssertTrue(element("appInformation.export.fromBuild").exists)
        XCTAssertTrue(text(containing: "From build 3’s answer").exists)
        XCTAssertTrue(text(containing: "Build 4 is still waiting for its encryption answer").exists)
        XCTAssertTrue(element("appInformation.export.isExempt").exists, "Yes, so the exempt question shows")
        XCTAssertTrue(element("appInformation.export.addKey").isEnabled)
        attach("info-export-first")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A Text's string is its AX value on macOS; a label shows in its label.
    private func text(containing string: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", string, string))
            .firstMatch
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
