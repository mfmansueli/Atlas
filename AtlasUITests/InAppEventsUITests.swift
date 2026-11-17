//
//  InAppEventsUITests.swift
//  AtlasUITests
//

import XCTest

/// In-App Events (⌘4) in its DEBUG scenes (board 40; Lumen Journal's
/// sample events, nothing reaches Apple): an event's languages with their
/// suggestions, accepting one or all, the event that goes with the
/// version, an ended event, and a new one.
@MainActor
final class InAppEventsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAnEventShowsItsSuggestedLanguages() {
        app.launch(debugScene: "ev")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.title")), "Winter Reflection 2026")
        XCTAssertEqual(text(of: element("events.status")), "Draft")
        XCTAssertEqual(text(of: element("events.languages.title")), "9 languages suggested by Claude Code")
        XCTAssertTrue(element("events.suggestion").exists)
        XCTAssertEqual(text(of: element("events.field.name.suggested")), "Winter-Reflexion in 31 Tagen")
        XCTAssertEqual(element("events.language.de-DE").label, "German, suggestion to review")
        XCTAssertEqual(text(of: element("events.preview.name")), "Winter-Reflexion in 31 Tagen")
        XCTAssertTrue(text(of: element("events.preview.note")).hasPrefix("Showing the suggestion."))
        attach("ev")
    }

    func testAcceptPutsTheTextsInTheFieldsAndUndoTakesThemBack() {
        app.launch(debugScene: "ev")
        XCTAssertTrue(element("events.suggestion.accept").waitForExistence(timeout: 15))
        element("events.suggestion.accept").click()
        let name = element("events.field.name")
        let accepted = NSPredicate(format: "value == %@", "Winter-Reflexion in 31 Tagen")
        let written = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: accepted, object: name)], timeout: 10)
        XCTAssertEqual(written, .completed, "\(String(describing: name.value))")
        XCTAssertEqual(text(of: element("events.languages.title")), "8 languages suggested by Claude Code")
        XCTAssertEqual(element("events.language.de-DE").label, "German, not pushed")
        app.buttons["Undo"].firstMatch.click()
        XCTAssertTrue(element("events.suggestion").waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: element("events.languages.title")), "9 languages suggested by Claude Code")
    }

    func testASuggestionSaysWhyItReadsThisWay() {
        app.launch(debugScene: "ev-br")
        let why = element("events.suggestion.why")
        XCTAssertTrue(why.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: why).contains("In Brazil December is summer"), text(of: why))
        XCTAssertEqual(text(of: element("events.field.name.suggested")), "Desafio de Fim de Ano")
        attach("ev-br")
    }

    func testArabicIsSuggestedToo() {
        app.launch(debugScene: "ev-ar")
        XCTAssertTrue(element("events.field.name.suggested").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.field.name.suggested")), "تحدي تأملات الشتاء")
        attach("ev-ar")
    }

    func testAcceptAllLanguagesAcceptsEverySuggestion() {
        app.launch(debugScene: "ev")
        let acceptAll = element("events.acceptAll")
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 15))
        acceptAll.click()
        let title = element("events.languages.title")
        let done = NSPredicate(format: "value == %@ OR label == %@", "Every language written or accepted", "Every language written or accepted")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: done, object: title)], timeout: 10), .completed, text(of: title))
        XCTAssertTrue(app.staticTexts["Accepted 9 languages for Winter Reflection Challenge. They’re in Review & Push."].exists)
        XCTAssertFalse(element("events.acceptAll").exists)
        attach("ev-done")
    }

    func testTheEventThatGoesWithTheVersionOpensTheSubmission() {
        app.launch(debugScene: "ev-mood")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.title")), "1.4 Mood Calendar")
        let status = element("events.status")
        let goesWith = NSPredicate(format: "value == %@ OR label == %@", "Goes with 1.4", "Goes with 1.4")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: goesWith, object: status)], timeout: 10), .completed, text(of: status))
        attach("ev-mood")
        let button = element("events.footer.button")
        XCTAssertEqual(button.label, "Open Submission")
        button.click()
        XCTAssertTrue(element("overview.version").waitForExistence(timeout: 10))
    }

    func testAnEndedEventShowsHowItDid() {
        app.launch(debugScene: "ev-ended")
        XCTAssertTrue(element("events.results").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.status")), "Ended")
        // The numbers arrive after the event shows.
        let views = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Event page views", "Event page views")
        XCTAssertTrue(app.descendants(matching: .any).matching(views).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(element("events.footer.button").label, "Duplicate Event")
        XCTAssertFalse(element("events.field.name").isEnabled, "An ended event's texts can't be changed")
        attach("ev-ended")
        element("events.footer.button").click()
        XCTAssertTrue(queued("Create “Gratitude Week copy”").waitForExistence(timeout: 5))
    }

    func testANewEventWaitsInReviewAndPush() {
        app.launch(debugScene: "ev-new")
        let name = element("events.new.name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        // Without a name it says what's missing and stays.
        element("events.new.add").click()
        XCTAssertEqual(text(of: element("events.new.note")), "Give the event a reference name. People never see it.")
        name.click()
        name.typeText("Spring Reset 2027")
        element("events.new.add").click()
        XCTAssertTrue(element("events.new.sheet").waitForNonExistence(timeout: 10))
        XCTAssertTrue(queued("Create “Spring Reset 2027”").waitForExistence(timeout: 5))
    }

    func testANewEventTakesADeepLinkAndWhetherItNeedsAPurchase() {
        app.launch(debugScene: "ev-new")
        let name = element("events.new.name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.click()
        name.typeText("Summer Streak 2027")
        // A deep link that isn't a URL says so and stays.
        let link = element("events.new.deepLink")
        link.click()
        link.typeText("open lumen")
        element("events.new.add").click()
        XCTAssertTrue(text(of: element("events.new.note")).hasPrefix("The deep link isn’t a valid URL."), text(of: element("events.new.note")))
        link.click()
        link.typeKey("a", modifierFlags: .command)
        link.typeText("lumen://summer")
        let purchase = element("events.new.purchase")
        XCTAssertTrue(purchase.exists)
        purchase.click()
        app.menuItems["Needs an in-app purchase"].firstMatch.click()
        attach("ev-new-filled")
        element("events.new.add").click()
        XCTAssertTrue(element("events.new.sheet").waitForNonExistence(timeout: 10))
        XCTAssertTrue(queued("Create “Summer Streak 2027”").waitForExistence(timeout: 5))
    }

    func testAnAppWithoutEventsOffersANewOne() {
        app.launch(debugScene: "ev-empty")
        XCTAssertTrue(element("events.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.empty.new").exists)
    }

    func testProposedArtIsAcceptedOrDismissedInImagesAndVideo() {
        app.launch(debugScene: "ev-art")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        let card = element("events.media.proposal.card")
        // Images and video sits below the fold.
        for _ in 0..<8 where !card.isHittable {
            element("events.editor").scroll(byDeltaX: 0, deltaY: -400)
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(element("events.media.preview.card").exists)
        XCTAssertTrue(element("events.media.preview.details").exists)
        XCTAssertTrue(element("events.media.ask").exists)
        attach("ev-art")

        element("events.media.accept.card").click()
        XCTAssertTrue(element("events.media.accept.card").waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("events.media.dismiss.card").label, "Remove")
        XCTAssertTrue(element("events.media.proposal.card").exists)

        element("events.media.dismiss.details").click()
        XCTAssertTrue(element("events.media.proposal.details").waitForNonExistence(timeout: 5))
        attach("ev-art-accepted")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// An event waiting in Review & Push, under the list.
    private func queued(_ title: String) -> XCUIElement {
        let row = NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "events.queued.", title)
        return app.descendants(matching: .any).matching(row).firstMatch
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
