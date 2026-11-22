//
//  InAppEventSuggestionsUITests.swift
//  AtlasUITests
//

import XCTest

/// An assistant's suggestions beside what's there, in their DEBUG scenes
/// ("7 Days of Gratitude", the clock at Nov 16, 12:00 GMT, nothing
/// reaches Apple). Its dates wait beside the ones the person queued, on
/// the event's page and in Review & Push, until the person accepts them
/// (they replace theirs) or dismisses them (theirs stay). Its revision of
/// a written language shows Now and Suggested with the changed words, and
/// only the texts it changes are queued.
@MainActor
final class InAppEventSuggestionsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Dates beside the person's

    func testAnAssistantsDatesWaitBesideThePersons() {
        app.launch(debugScene: "ev-dates-suggested")
        let suggestion = element("events.details.dates.alternative")
        XCTAssertTrue(suggestion.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: element("events.details.dates.alternative.reason")).contains("Start on a Monday"))
        // The card's date is the person's in both; the event's start and end move.
        XCTAssertEqual(yoursAndSuggested("publishStart").yours, yoursAndSuggested("publishStart").suggested)
        XCTAssertNotEqual(yoursAndSuggested("eventStart").yours, yoursAndSuggested("eventStart").suggested)
        XCTAssertNotEqual(yoursAndSuggested("eventEnd").yours, yoursAndSuggested("eventEnd").suggested)
        // The person's own date is still what's queued.
        XCTAssertTrue(element("events.details.dates.publishStart.pending").exists)
        XCTAssertFalse(element("events.details.dates.eventStart.pending").exists)
        attach("ev-dates-suggested")
    }

    func testAcceptingTheSuggestionReplacesThePersonsDates() {
        app.launch(debugScene: "ev-dates-suggested")
        let accept = element("events.details.dates.alternative.accept")
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        accept.click()
        XCTAssertTrue(element("events.details.dates.alternative").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.details.dates.eventStart.pending").waitForExistence(timeout: 5))
        XCTAssertTrue(element("events.details.dates.eventEnd.pending").exists)
        XCTAssertTrue(element("events.details.dates.publishStart.pending").exists)
        attach("ev-dates-suggested-accepted")
    }

    func testDismissingTheSuggestionKeepsThePersonsDates() {
        app.launch(debugScene: "ev-dates-suggested")
        let dismiss = element("events.details.dates.alternative.dismiss")
        XCTAssertTrue(dismiss.waitForExistence(timeout: 20))
        dismiss.click()
        XCTAssertTrue(element("events.details.dates.alternative").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.details.dates.publishStart.pending").exists)
        XCTAssertFalse(element("events.details.dates.eventStart.pending").exists)
        XCTAssertFalse(element("events.details.dates.eventEnd.pending").exists)
    }

    func testReviewAndPushAsksWhichDatesToPush() {
        app.launch(debugScene: "ev-dates-suggested")
        XCTAssertTrue(element("events.details.dates.alternative").waitForExistence(timeout: 20))
        app.typeKey("p", modifierFlags: [.command, .shift])
        let theirs = app.buttons["review.pickAssistant"]
        XCTAssertTrue(theirs.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["review.pickYours"].exists)
        XCTAssertTrue(theirs.label.hasPrefix("Keep Claude Code:"), theirs.label)
        attach("ev-dates-suggested-review")

        theirs.click()
        XCTAssertTrue(theirs.waitForNonExistence(timeout: 5))
    }

    // MARK: - A revision of a written language

    func testARevisionShowsNowAndSuggestedWithTheChangedWords() {
        app.launch(debugScene: "ev-text-revision")
        let card = element("events.revision")
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: element("events.revision.why")).contains("now ends on Wednesday"))
        let now = element("events.revision.longDescription.now")
        let suggested = element("events.revision.longDescription.suggested")
        XCTAssertTrue(text(of: now).hasSuffix("milestone by Sunday."), text(of: now))
        XCTAssertTrue(text(of: suggested).contains("milestone by November 26."), text(of: suggested))
        XCTAssertTrue(text(of: suggested).contains("Changed: November 26"), text(of: suggested))
        // Only the long description changes: the name and short one stay.
        XCTAssertFalse(element("events.revision.name").exists)
        XCTAssertFalse(element("events.revision.shortDescription").exists)
        XCTAssertTrue(element("events.revision.dismiss").exists)
        XCTAssertTrue(element("events.revision.useAndEdit").exists)
        XCTAssertTrue(element("events.revision.accept").exists)
        XCTAssertTrue(value(of: element("events.field.longDescription")).hasSuffix("by Sunday."))
        attach("ev-text-revision")
    }

    func testAcceptingARevisionQueuesOnlyTheTextItChanges() {
        app.launch(debugScene: "ev-text-revision")
        let accept = element("events.revision.accept")
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        accept.click()
        XCTAssertTrue(element("events.revision").waitForNonExistence(timeout: 5))
        XCTAssertTrue(value(of: element("events.field.longDescription")).hasSuffix("by November 26."))
        XCTAssertEqual(value(of: element("events.field.name")), "7 Days of Gratitude")
        let toast = app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Accepted English' OR label BEGINSWITH 'Accepted English'"))
        XCTAssertTrue(toast.firstMatch.waitForExistence(timeout: 5))
        attach("ev-text-revision-accepted")
    }

    func testUseAndEditPutsTheRevisionInToEdit() {
        app.launch(debugScene: "ev-text-revision")
        let useAndEdit = element("events.revision.useAndEdit")
        XCTAssertTrue(useAndEdit.waitForExistence(timeout: 20))
        useAndEdit.click()
        XCTAssertTrue(element("events.revision").waitForNonExistence(timeout: 5))
        let field = element("events.field.longDescription")
        XCTAssertTrue(value(of: field).hasSuffix("by November 26."))
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: focused, object: field)], timeout: 5), .completed)
    }

    func testDismissingARevisionKeepsTheWrittenText() {
        app.launch(debugScene: "ev-text-revision")
        let dismiss = element("events.revision.dismiss")
        XCTAssertTrue(dismiss.waitForExistence(timeout: 20))
        dismiss.click()
        XCTAssertTrue(element("events.revision").waitForNonExistence(timeout: 5))
        XCTAssertTrue(value(of: element("events.field.longDescription")).hasSuffix("by Sunday."))
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A date's two columns in the suggestion beside the person's dates.
    private func yoursAndSuggested(_ field: String) -> (yours: String, suggested: String) {
        let prefix = "events.details.dates.alternative.\(field)"
        // The suggested date reads “Shows from: 18 Nov at 12:00, changed” to
        // VoiceOver: compare the dates alone.
        var suggested = text(of: element(prefix))
        if let colon = suggested.range(of: ": ") { suggested = String(suggested[colon.upperBound...]) }
        if suggested.hasSuffix(", changed") { suggested = String(suggested.dropLast(", changed".count)) }
        return (text(of: element("\(prefix).yours")), suggested)
    }

    /// A text field's text.
    private func value(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
