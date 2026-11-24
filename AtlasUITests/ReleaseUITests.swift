//
//  ReleaseUITests.swift
//  AtlasUITests
//

import XCTest

/// Submit for Review and release in their DEBUG scenes (board 39; Lumen
/// Journal 1.4, nothing reaches Apple): the Overview's version card before
/// and after submitting, the Submit sheet, and what each status offers.
@MainActor
final class ReleaseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testBeforeSubmittingTheCardSaysWhatGoesAndWhatIsMissing() {
        app.launch(debugScene: "rel-prep")
        XCTAssertTrue(element("overview.version").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.title")), "Lumen Journal 1.4 is almost ready for App Review")
        XCTAssertEqual(text(of: element("overview.version.pill")), "Prepare for Submission")
        XCTAssertTrue(app.staticTexts["Build 1.4 (212)"].exists)
        XCTAssertTrue(app.staticTexts["What’s New in 9 of 10 languages"].exists)
        XCTAssertTrue(app.staticTexts["Italian is missing; a suggestion is waiting"].exists)
        XCTAssertTrue(app.staticTexts["In-App Event “Mood Calendar”"].exists)
        attach("rel-prep")
        element("overview.version.submit").click()
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 10))
    }

    func testTheSheetSaysExactlyWhatIsMissingUntilItIsThere() {
        app.launch(debugScene: "rel-sheet")
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: element("submit.title")), "Submit Lumen Journal 1.4 for App Review")
        XCTAssertEqual(text(of: element("submit.footer")), "To submit, add What’s New in Italian and answer the encryption question.")
        XCTAssertFalse(element("submit.submit").isEnabled)
        XCTAssertTrue(element("submit.encryption.needed").exists)
        XCTAssertFalse(element("submit.build.213").isEnabled, "A build Apple is still processing can’t be chosen")
        attach("rel-sheet")

        element("submit.whatsNew.accept.it").click()
        let footer = element("submit.footer")
        let needed = "To submit, answer the encryption question."
        let encryptionOnly = NSPredicate(format: "value == %@ OR label == %@", needed, needed)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: encryptionOnly, object: footer)], timeout: 15), .completed, text(of: footer))
        element("submit.encryption.exempt").click()
        let submit = element("submit.submit")
        XCTAssertTrue(submit.isEnabled)
        // The accepted What's New isn't pushed yet: it goes with the submission.
        XCTAssertEqual(submit.label, "Push and Submit for Review")
        attach("rel-sheet-ok")
        submit.click()
        XCTAssertTrue(element("submit.sheet").waitForNonExistence(timeout: 20))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Waiting for Review")
        XCTAssertEqual(text(of: element("overview.version.title")), "1.4 is waiting for App Review")
    }

    /// A build uploaded after the app was opened shows: the sheet reads
    /// the builds when it opens, every minute after, and on Check Again.
    func testTheSheetLooksForNewBuilds() {
        app.launch(debugScene: "rel-sheet")
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("submit.build.212").waitForExistence(timeout: 5))
        let checkAgain = element("submit.checkBuilds")
        XCTAssertTrue(checkAgain.waitForExistence(timeout: 10), "Reading the builds on opening ends with Check Again")
        checkAgain.click()
        XCTAssertTrue(checkAgain.waitForExistence(timeout: 10))
        XCTAssertTrue(element("submit.build.212").exists)
    }

    func testChangesNotPushedYetGoWithTheSubmission() {
        app.launch(debugScene: "rel-sheet-push")
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 20))
        let push = element("submit.pushChanges")
        XCTAssertTrue(push.exists)
        XCTAssertTrue(text(of: push).contains("Push 4 changes with this submission"), text(of: push))
        attach("rel-sheet-push")
    }

    func testWaitingForReviewCanBeCanceled() {
        app.launch(debugScene: "rel-wait")
        XCTAssertTrue(element("overview.version.steps").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Waiting for Review")
        XCTAssertEqual(element("overview.version.step.1").label, "Waiting for Review, now, Usually about a day")
        attach("rel-wait")
        element("overview.version.cancel").click()
        let confirm = element("overview.version.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()
        XCTAssertTrue(element("overview.version.submit").waitForExistence(timeout: 10), "Back to Prepare for Submission")
    }

    func testAnApprovedVersionIsReleasedByThePerson() {
        app.launch(debugScene: "rel-pending")
        let release = element("overview.version.release")
        XCTAssertTrue(release.waitForExistence(timeout: 15))
        XCTAssertEqual(release.label, "Release 1.4 Now")
        XCTAssertEqual(text(of: element("overview.version.title")), "1.4 is approved and waiting for you")
        attach("rel-pending")
        release.click()
        let confirm = element("overview.version.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()
        XCTAssertTrue(element("overview.version.phased").waitForExistence(timeout: 10))
    }

    func testAPhasedReleasePausesAndResumes() {
        app.launch(debugScene: "rel-phased")
        let pause = element("overview.version.pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Phased Release · Day 3 of 7")
        XCTAssertEqual(pause.label, "Pause Phased Release")
        attach("rel-phased")
        pause.click()
        let paused = NSPredicate(format: "label == %@", "Resume Phased Release")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: paused, object: pause)], timeout: 10), .completed, pause.label)
        XCTAssertEqual(text(of: element("overview.version.pill")), "Phased Release paused")
        attach("rel-paused")
    }

    func testARejectedVersionSaysWhereApplesMessageIs() {
        app.launch(debugScene: "rel-rejected")
        XCTAssertTrue(element("overview.version.rejection").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Rejected")
        XCTAssertTrue(element("overview.version.readMessage").exists)
        XCTAssertTrue(element("overview.version.resubmit").exists)
        attach("rel-rejected")
        element("overview.version.editReview").click()
        XCTAssertTrue(element("workspace.appInformation").waitForExistence(timeout: 10))
    }

    func testAWriteAppStoreConnectRefusesSaysSo() {
        app.launch(debugScene: "rel-refused")
        XCTAssertTrue(element("overview.version.cancel").waitForExistence(timeout: 15))
        element("overview.version.cancel").click()
        element("overview.version.confirm").click()
        XCTAssertTrue(element("overview.version.error").waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: element("overview.version.pill")), "Waiting for Review", "Nothing changed")
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
