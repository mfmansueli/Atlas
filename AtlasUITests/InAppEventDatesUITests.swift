//
//  InAppEventDatesUITests.swift
//  AtlasUITests
//

import XCTest

/// A draft's dates in their DEBUG scenes (Lumen Journal's sample events,
/// the clock at Nov 16, 12:00 GMT, nothing reaches Apple). Alba 1.2.0: App
/// Store Connect refused "7 Days of Gratitude" because its card was set to
/// show from a time that had passed. The event page lists it with the
/// "Shows from" that works, the Event card's row says it has passed, the
/// footer isn't "Ready", and Fix… goes to the dates; the Submit sheet
/// blocks it with Fix…, and App Review's time only warns.
@MainActor
final class InAppEventDatesUITests: XCTestCase {
    private var app: XCUIApplication!
    private let seven = "event-seven-days"
    private let mood = "event-mood"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - The event's page

    func testACardDateThatHasPassedIsOnTheListTheRowAndTheFooter() {
        app.launch(debugScene: "ev-dates-past")
        let item = element("events.review.publishStartPassed")
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        XCTAssertTrue(shows(item, "which has passed. App Store Connect only takes dates in the future."))
        XCTAssertTrue(element("events.review.publishStartPassed.fix").exists, "Show from … is offered")
        XCTAssertTrue(element("events.review.publishStartPassed.change").exists)

        let row = element("events.settings.publish.problem")
        XCTAssertTrue(row.exists)
        XCTAssertTrue(text(of: row).hasPrefix("Show time today at"), text(of: row))
        XCTAssertTrue(text(of: row).hasSuffix("(your time) has passed"), text(of: row))
        XCTAssertTrue(element("events.settings.publish.fix").exists)

        let footer = element("events.footer.text")
        XCTAssertTrue(footer.exists)
        XCTAssertFalse(text(of: footer).hasPrefix("Ready"), text(of: footer))
        XCTAssertTrue(text(of: footer).contains("show its card from a time still ahead"), text(of: footer))
        attach("ev-dates-past")
    }

    func testFixGoesToTheDates() {
        app.launch(debugScene: "ev-dates-past")
        let fix = element("events.settings.publish.fix")
        XCTAssertTrue(fix.waitForExistence(timeout: 20))
        fix.click()
        XCTAssertTrue(element("events.details.dates").waitForExistence(timeout: 5))
        XCTAssertTrue(element("events.details.dates.publishStart").exists)
        XCTAssertTrue(element("events.details.dates.eventStart").exists)
        XCTAssertTrue(element("events.details.dates.eventEnd").exists)
        XCTAssertTrue(text(of: element("events.details.dates.zone")).hasPrefix("Times in your time zone,"))
        XCTAssertTrue(element("events.details.dates.problem").exists)
        attach("ev-dates-past-fix")
    }

    func testShowingFromTheSuggestionQueuesItAndUndoTakesItBack() {
        app.launch(debugScene: "ev-dates-past")
        let suggestion = element("events.review.publishStartPassed.fix")
        XCTAssertTrue(suggestion.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: suggestion).hasPrefix("Show from"))
        suggestion.click()

        let pending = element("events.details.dates.publishStart.pending")
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertFalse(element("events.settings.publish.problem").exists, "New dates wait in Review & Push")
        XCTAssertTrue(text(of: element("events.settings.publish")).hasSuffix("New dates wait in Review & Push."))
        XCTAssertTrue(text(of: element("events.footer.text")).hasPrefix("To submit: push its changes."))
        attach("ev-dates-past-queued")

        element("events.details.dates.publishStart.undo").click()
        XCTAssertTrue(pending.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.settings.publish.problem").waitForExistence(timeout: 5))
    }

    func testDatesWaitingInReviewAndPushFillTheNeed() {
        app.launch(debugScene: "ev-dates-queued")
        XCTAssertTrue(element("events.details.dates.publishStart.pending").waitForExistence(timeout: 20))
        XCTAssertTrue(shows(element("events.review.publishStartPassed"), "Waits in Review & Push"))
        XCTAssertFalse(element("events.details.dates.problem").exists)
        attach("ev-dates-queued")
    }

    func testAnEventStartingSoonWarnsWithoutBlocking() {
        app.launch(debugScene: "ev-dates-soon")
        let warning = element("events.review.warning.eventStartsSoon")
        XCTAssertTrue(warning.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: element("events.review.warning.eventStartsSoon.text")).hasPrefix("The event starts in 20 hours."))
        XCTAssertTrue(element("events.review.warning.eventStartsSoon.fix").exists)
        // A warning never blocks: nothing about its dates is missing.
        XCTAssertFalse(element("events.review.eventStartPassed").exists)
        XCTAssertFalse(element("events.review.publishStartPassed").exists)
        XCTAssertFalse(text(of: element("events.footer.text")).contains("dates"))
        attach("ev-dates-soon")
    }

    func testDatesAtlasCantSendSayWhy() {
        app.launch(debugScene: "ev-dates-unknown")
        let reason = element("events.details.dates.cantChange")
        XCTAssertTrue(reason.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: reason).hasPrefix("Atlas doesn’t know which countries or regions"))
        XCTAssertTrue(element("events.settings.publish.problem").exists)
        XCTAssertFalse(element("events.settings.publish.fix").exists, "Changed in App Store Connect")
        attach("ev-dates-unknown")
    }

    // MARK: - The Submit sheet

    func testATickedEventWhoseCardDateHasPassedBlocksSubmit() {
        app.launch(debugScene: "rel-sheet-ev-dates")
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 20))
        let missing = element("submit.event.\(mood).missing.publishStartPassed")
        XCTAssertTrue(missing.waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: missing).contains("which has passed"))
        XCTAssertEqual(text(of: element("submit.footer")), "To submit, fix or untick “Mood Calendar”.")
        XCTAssertFalse(element("submit.submit").isEnabled)
        attach("rel-sheet-ev-dates")

        element("submit.event.\(mood).fix").click()
        XCTAssertTrue(element("submit.sheet").waitForNonExistence(timeout: 10))
        XCTAssertTrue(element("events.details.dates").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.review.publishStartPassed").exists)
    }

    func testAnEventStartingSoonWarnsInTheSheetAndKeepsSubmitOn() {
        app.launch(debugScene: "rel-sheet-ev-soon")
        let warning = element("submit.event.\(mood).reviewTime.eventStartsSoon")
        XCTAssertTrue(warning.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: warning).contains("App Review usually takes up to 2 days"))
        XCTAssertTrue(element("submit.submit").isEnabled)
        attach("rel-sheet-ev-soon")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Whether `element`, or a text in it, says `part`: a row that
    /// contains its texts has no words of its own.
    private func shows(_ element: XCUIElement, _ part: String) -> Bool {
        if text(of: element).contains(part) { return true }
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", part, part)
        return element.descendants(matching: .staticText).matching(predicate).firstMatch.exists
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
