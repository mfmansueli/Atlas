//
//  InAppEventsUITests.swift
//  AtlasUITests
//

import XCTest

/// In-App Events (⌘5) in its DEBUG scenes (board 40; Lumen Journal's
/// sample events, nothing reaches Apple): the gallery and an event's page,
/// the name's menu of the other events, an event's languages with their
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

    // MARK: - Gallery and page

    func testTheGalleryOpensAnEventsPageAndEventsGoesBack() {
        app.launch(debugScene: "ev-list")
        let winter = element("events.tile.event-winter")
        XCTAssertTrue(winter.waitForExistence(timeout: 15))
        XCTAssertTrue(winter.label.contains("3 concepts to choose from"), winter.label)
        XCTAssertTrue(element("events.tile.event-mood").label.contains("Goes with 1.4"), element("events.tile.event-mood").label)
        XCTAssertTrue(element("events.tile.event-gratitude").exists)
        attach("ev-list")
        winter.click()
        XCTAssertTrue(element("events.hero").waitForExistence(timeout: 10))
        XCTAssertTrue(element("events.page.name").label.contains("Winter Reflection 2026"))
        element("events.page.back").click()
        XCTAssertTrue(element("events.gallery").waitForExistence(timeout: 10))
        XCTAssertFalse(element("events.hero").exists)
    }

    func testTheNameIsAMenuOfTheOtherEvents() {
        app.launch(debugScene: "ev-menu")
        XCTAssertTrue(element("events.menu").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.menu.event-winter").isSelected)
        attach("ev-menu")
        element("events.menu.event-gratitude").click()
        XCTAssertTrue(waitForLabel(containing: "Gratitude Week", in: element("events.page.name")))
        XCTAssertEqual(text(of: element("events.status")), "Ended")
        element("events.page.name").click()
        XCTAssertTrue(element("events.menu.all").waitForExistence(timeout: 5))
        element("events.menu.all").click()
        XCTAssertTrue(element("events.gallery").waitForExistence(timeout: 10))
    }

    func testAnEventShowsItsSuggestedLanguages() {
        app.launch(debugScene: "ev")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.page.name").label.contains("Winter Reflection 2026"))
        XCTAssertEqual(text(of: element("events.status")), "Draft")
        XCTAssertEqual(text(of: element("events.languages.title")), "9 languages suggested by Claude Code")
        XCTAssertTrue(element("events.suggestion").exists)
        XCTAssertEqual(text(of: element("events.field.name.suggested")), "Winter-Reflexion in 31 Tagen")
        XCTAssertEqual(element("events.language.de-DE").label, "German, suggestion to review")
        // The card's texts are on its art button, for VoiceOver.
        let card = element("events.preview.card").value as? String ?? ""
        XCTAssertTrue(card.hasPrefix("Winter-Reflexion in 31 Tagen"), card)
        XCTAssertTrue(text(of: element("events.preview.note")).hasPrefix("Text: the German suggestion."), text(of: element("events.preview.note")))
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

    /// Apple's In-App Events page: a specific price is rejected. The field
    /// warns, and the person can still keep it.
    func testAPriceInAnEventTextIsWarned() {
        app.launch(debugScene: "ev")
        let name = element("events.field.name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        scrollTo(name)
        XCTAssertFalse(element("events.field.name.guideline").exists)
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Winter for $4.99")
        let warning = element("events.field.name.guideline")
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: warning).contains("Guideline 2.3.13"), text(of: warning))
        XCTAssertEqual(name.value as? String, "Winter for $4.99")
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
        // The card's texts are on its art button, for VoiceOver.
        let card = element("events.preview.card").value as? String ?? ""
        XCTAssertTrue(card.hasPrefix("تحدي تأملات الشتاء"), card)
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
        XCTAssertTrue(app.staticTexts["Accepted 9 languages for Winter Reflection Challenge. They’re waiting in Review & Push, top right."].exists)
        XCTAssertFalse(element("events.acceptAll").exists)
        attach("ev-accepted")
    }

    /// Dismiss All beside Accept All Languages: every suggestion goes, the
    /// languages read as not written, and the toast's Undo brings them back.
    func testDismissAllTakesEverySuggestionAndUndoBringsThemBack() {
        app.launch(debugScene: "ev")
        let dismissAll = element("events.dismissAll")
        XCTAssertTrue(dismissAll.waitForExistence(timeout: 15))
        XCTAssertEqual(dismissAll.label, "Dismiss All, 9 suggested")
        dismissAll.click()
        let title = element("events.languages.title")
        let dismissed = NSPredicate(format: "value ENDSWITH %@ OR label ENDSWITH %@", "not written yet", "not written yet")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: dismissed, object: title)], timeout: 10), .completed, text(of: title))
        XCTAssertTrue(app.staticTexts["Dismissed 9 languages for Winter Reflection Challenge."].exists)
        XCTAssertFalse(element("events.dismissAll").exists)
        XCTAssertFalse(element("events.acceptAll").exists)
        XCTAssertFalse(element("events.suggestion").exists)
        attach("ev-dismissed")
        app.buttons["Undo"].firstMatch.click()
        XCTAssertTrue(element("events.suggestion").waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: element("events.languages.title")), "9 languages suggested by Claude Code")
        XCTAssertTrue(element("events.dismissAll").exists)
    }

    func testTheEventThatGoesWithTheVersionOpensTheSubmission() {
        app.launch(debugScene: "ev-mood")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.page.name").label.contains("1.4 Mood Calendar"))
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
        XCTAssertEqual(text(of: element("events.art.line")), "Event card and event details")
        XCTAssertEqual(text(of: element("events.art.detail")), "As they were on the App Store.")
        XCTAssertEqual(element("events.footer.button").label, "Duplicate Event")
        XCTAssertFalse(element("events.field.name").isEnabled, "An ended event's texts can't be changed")
        attach("ev-ended")
        element("events.footer.button").click()
        // The copy waits in the gallery.
        element("events.page.back").click()
        XCTAssertTrue(queued("Gratitude Week copy").waitForExistence(timeout: 5))
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
        XCTAssertTrue(queued("Spring Reset 2027").waitForExistence(timeout: 5))
        attach("ev-new-queued")
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
        XCTAssertTrue(queued("Summer Streak 2027").waitForExistence(timeout: 5))
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
        scrollTo(card)
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

    /// In Review & Push's list, a click on an event image or video opens it
    /// large; Esc closes only the viewer.
    func testArtInReviewAndPushOpensLarge() {
        app.launch(debugScene: "ev-art")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        app.typeKey("p", modifierFlags: [.command, .shift])
        let thumbnails = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.artwork.'"))
        let first = thumbnails.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Each art change's thumbnail is a button")
        first.click()
        let viewer = element("review.viewer")
        XCTAssertTrue(viewer.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: element("review.viewer.title")).contains("Winter"), text(of: element("review.viewer.title")))
        attach("review-art-viewer")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(viewer.waitForNonExistence(timeout: 5))
        XCTAssertTrue(first.exists, "Esc closes the viewer, not Review & Push")
    }

    /// ⌘Q quits with a sheet open, as the menu bar's Quit does, instead of
    /// doing nothing.
    func testQuitWorksWithReviewAndPushOpen() {
        app.launch(debugScene: "ev-art")
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
        app.typeKey("p", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.artwork.'")).firstMatch.waitForExistence(timeout: 10))
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15), "Atlas quits with the sheet open")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The page scrolls: what's below the fold comes up.
    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            element("events.editor").scroll(byDeltaX: 0, deltaY: -400)
        }
    }

    /// A new event waiting in Review & Push, as a tile in the gallery.
    private func queued(_ name: String) -> XCUIElement {
        let tile = NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "events.queued.", name)
        return app.descendants(matching: .any).matching(tile).firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitForLabel(containing part: String, in element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if element.exists, element.label.contains(part) { return true }
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
