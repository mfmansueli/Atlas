//
//  EventArtworkUITests.swift
//  AtlasUITests
//

import XCTest

/// In-App Events · artwork from Claude (boards 40 and 47) in its
/// DEBUG scenes, on the Winter Reflection Challenge (its details image is
/// missing): the Brief, the Artwork panel on the event's page, the viewer
/// over the window, full screen, and Pro. Claude Code never starts: the
/// scenes hand the page a made-up run, and nothing reaches Apple.
@MainActor
final class EventArtworkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - The Brief

    func testTheBriefClosesAndTheConceptsFillInOnThePage() {
        app.launch(debugScene: "ea-brief")
        XCTAssertTrue(element("events.art.title").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.art.title")), "Artwork for Winter Reflection 2026")
        XCTAssertTrue(text(of: element("events.art.subtitle")).hasSuffix("They are drawn while you keep working."))
        XCTAssertTrue(element("events.art.brief.text").exists)
        // The row's "Recommended" pill carries the same identifier.
        XCTAssertTrue(app.buttons["events.art.look.newLook"].isSelected)
        XCTAssertTrue(text(of: element("events.art.summary")).hasPrefix("3 concepts, each a matching pair"))
        attach("ea-brief")

        element("events.art.make").click()
        XCTAssertTrue(element("events.art.sheet").waitForNonExistence(timeout: 10))
        XCTAssertTrue(element("events.art.panel.drawing").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("events.art.line")), "Claude is drawing · 0 of 3 ready")
        XCTAssertTrue(element("events.art.row.1").exists)
        XCTAssertTrue(element("events.art.stop").exists)
        XCTAssertFalse(element("events.art.use").exists)
        attach("ea-making-started")
    }

    func testTheOptionsChangeWhatComesBack() {
        app.launch(debugScene: "ea-brief-opts")
        XCTAssertTrue(element("events.art.result").waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: element("events.art.result")).contains("plus a moving version of each"))
        // The board's options: words, motion and Start from a Template.
        XCTAssertTrue(app.buttons["events.art.look.template"].isSelected)
        XCTAssertTrue(text(of: element("events.art.summary")).hasPrefix("3 concepts from Atlas’s event layouts"))
        XCTAssertTrue(text(of: element("events.art.summary")).contains("about 14 min"))
        attach("ea-brief-opts")
    }

    /// No design project yet: a new look isn't offered, the templates are.
    func testWithoutADesignProjectTemplatesComeFirst() {
        app.launch(debugScene: "ea-brief-nods")
        XCTAssertTrue(element("events.art.look.template").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["events.art.look.template"].isSelected)
        XCTAssertFalse(app.buttons["events.art.look.newLook"].isEnabled)
        attach("ea-brief-nods")
    }

    /// The minimum window (boards 40 and 47), the sidebar hidden: the
    /// gallery, the page, the viewer and the Brief keep their controls in
    /// view.
    func testTheMinimumWindowKeepsEverything() {
        app.launch(debugScene: "ev-s")
        XCTAssertTrue(element("events.gallery").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.gallery").isHittable)
        attach("ev-s")
        app.terminate()

        app.launch(debugScene: "ev-event-s")
        XCTAssertTrue(element("events.hero").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.hero").isHittable)
        attach("ev-event-s")
        app.terminate()

        app.launch(debugScene: "ev-view-s")
        XCTAssertTrue(element("events.art.viewer.close").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.art.viewer.close").isHittable)
        XCTAssertTrue(element("events.art.viewer.use").isHittable)
        attach("ev-view-s")
        app.terminate()

        app.launch(debugScene: "ea-brief-s")
        XCTAssertTrue(element("events.art.make").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.art.make").isHittable)
        XCTAssertTrue(element("events.art.cancel").isHittable)
        attach("ea-brief-s")
    }

    // MARK: - The Artwork panel

    func testNothingMadeAsksForTheMissingImage() {
        app.launch(debugScene: "ev-missing")
        XCTAssertTrue(element("events.art.panel.missing").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.art.line")), "Event details image missing")
        XCTAssertTrue(element("events.art.pair.missing.details").exists)
        XCTAssertTrue(element("events.art.make").exists)
        XCTAssertTrue(element("events.art.files").exists)
        XCTAssertFalse(element("events.art.view").exists)
        attach("ev-missing")
    }

    func testStopAddsNothingToTheEvent() {
        app.launch(debugScene: "ev-making")
        XCTAssertTrue(element("events.art.stop").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.art.line")), "Claude is drawing · 1 of 3 ready")
        XCTAssertTrue(element("events.art.progress").exists)
        attach("ev-making")
        element("events.art.stop").click()
        XCTAssertEqual(waitForText(in: element("toast.text")), "Stopped. Nothing was added to the event.")
        XCTAssertTrue(element("events.art.panel.missing").waitForExistence(timeout: 5))
    }

    func testAConceptClickedShowsOnTheCardAndUseQueuesItWithUndo() {
        app.launch(debugScene: "ev-event")
        XCTAssertTrue(element("events.art.panel.ready").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.art.line")), "3 concepts are ready")
        XCTAssertTrue(text(of: element("events.preview.note")).hasPrefix("Previewing “Snowfall Path”, not chosen yet."))
        attach("ev-event")

        element("events.art.row.b").click()
        XCTAssertTrue(waitForText("Previewing “Quiet Lantern”", prefixOf: element("events.preview.note")))
        XCTAssertTrue(element("events.art.row.b").isSelected)
        element("events.art.use").click()
        XCTAssertEqual(
            waitForText(in: element("toast.text")),
            "“Quiet Lantern” is the artwork for Winter Reflection 2026. Both images are in Review & Push."
        )
        XCTAssertTrue(element("events.art.panel.used").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("events.art.line")), "“Quiet Lantern”")
        XCTAssertFalse(text(of: element("events.preview.note")).hasPrefix("Previewing"))
        attach("ev-used-b")

        app.buttons["Undo"].firstMatch.click()
        XCTAssertTrue(element("events.art.panel.ready").waitForExistence(timeout: 5))
    }

    func testChangeOffersTheOtherConceptsAndKeepCurrentGoesBack() {
        app.launch(debugScene: "ev-used")
        XCTAssertTrue(element("events.art.panel.used").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("events.art.line")), "“Snowfall Path”")
        XCTAssertTrue(text(of: element("events.art.detail")).hasSuffix("· in Review & Push"))
        element("events.art.change").click()
        XCTAssertTrue(element("events.art.panel.changing").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("events.art.line")), "Choose another concept")
        XCTAssertTrue(element("events.art.row.a").value.map { "\($0)".hasPrefix("In use") } ?? false)
        element("events.art.row.c").click()
        XCTAssertTrue(waitForText("Previewing “Aurora Pages”", prefixOf: element("events.preview.note")))
        attach("ev-change")
        element("events.art.keep").click()
        XCTAssertTrue(element("events.art.panel.used").waitForExistence(timeout: 5))
        XCTAssertFalse(text(of: element("events.preview.note")).hasPrefix("Previewing"))
    }

    /// Free: Make the Artwork opens the paywall; Choose Files… stays.
    func testMakeTheArtworkIsPro() {
        app.launch(debugScene: "ev-free")
        XCTAssertTrue(element("events.art.make").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.art.files").isEnabled)
        attach("ev-free")
        element("events.art.make").click()
        XCTAssertTrue(element("paywall.context.title").waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: element("paywall.context.title")), "Event artwork is part of Pro")
        XCTAssertFalse(element("events.art.title").exists)
    }

    // MARK: - The viewer

    /// The details image says when the event runs under its name, as the
    /// App Store does and as the page's preview shows it.
    func testTheViewersDetailsImageSaysWhenTheEventRuns() {
        app.launch(debugScene: "ev-view-details")
        XCTAssertTrue(element("events.art.viewer.storeText").waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: element("events.art.viewer.storeText")).contains("Starts "), text(of: element("events.art.viewer.storeText")))
        attach("ev-view-details")
    }

    func testViewFullSizeCoversTheWindowAndGoesRoundTheConcepts() {
        app.launch(debugScene: "ev-event")
        XCTAssertTrue(element("events.art.view").waitForExistence(timeout: 15))
        element("events.art.view").click()
        XCTAssertTrue(element("events.art.viewer").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("events.art.viewer.title")), "Snowfall Path")
        XCTAssertEqual(text(of: element("events.art.viewer.subtitle")), "Concept 1 of 3 · Claude · Event card · 1920 × 1080")
        XCTAssertTrue(element("events.art.viewer.storeText").exists)
        XCTAssertFalse(element("events.art.textAreaShown").exists)
        attach("ev-view")

        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(waitForText("Quiet Lantern", prefixOf: element("events.art.viewer.title")))
        element("events.art.viewer.previous").click()
        element("events.art.viewer.previous").click()
        XCTAssertTrue(waitForText("Aurora Pages", prefixOf: element("events.art.viewer.title")))
        element("events.art.viewer.kind.details").click()
        XCTAssertTrue(waitForText("Concept 3 of 3 · Claude · Event details", prefixOf: element("events.art.viewer.subtitle")))
        element("events.art.viewer.textArea").click()
        XCTAssertTrue(element("events.art.textAreaShown").waitForExistence(timeout: 5))
        element("events.art.viewer.text").click()
        XCTAssertTrue(element("events.art.viewer.storeText").waitForNonExistence(timeout: 5))

        // Esc closes it, and the page previews where it was left.
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("events.art.viewer").waitForNonExistence(timeout: 5))
        XCTAssertTrue(text(of: element("events.preview.note")).hasPrefix("Previewing “Aurora Pages”"))
    }

    func testTheTextReadsInAnotherLanguageRightToLeft() {
        app.launch(debugScene: "ev-view-ar")
        XCTAssertTrue(element("events.art.viewer").waitForExistence(timeout: 15))
        let language = element("events.art.viewer.language")
        XCTAssertTrue(language.label.hasPrefix("Language: Arabic."), language.label)
        XCTAssertTrue(text(of: element("events.art.viewer.storeText")).contains("تحدي تأملات الشتاء"))
        attach("ev-view-ar")
        language.click()
        let english = element("languageBar.menu.en-US")
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.click()
        XCTAssertTrue(waitForText("Winter Reflection Challenge", containedIn: element("events.art.viewer.storeText")))
    }

    func testAskForChangesRedrawsThePairInPlace() {
        app.launch(debugScene: "ev-view-ask")
        XCTAssertTrue(element("events.art.askPanel").waitForExistence(timeout: 15))
        XCTAssertEqual(element("events.art.request").value as? String, "Make the moon larger and move the lights a little to the right.")
        XCTAssertFalse(element("events.art.viewer.ask").isEnabled)
        attach("ev-view-ask")
        element("events.art.send").click()
        XCTAssertTrue(element("events.art.askPanel").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.art.viewer.busy").waitForExistence(timeout: 5))
        XCTAssertFalse(element("events.art.viewer.ask").isEnabled)
        XCTAssertFalse(element("events.art.viewer.use").isEnabled)
        attach("ev-view-redo")
    }

    func testUseFromTheViewerClosesItWithThePairQueued() {
        app.launch(debugScene: "ev-view-b")
        XCTAssertTrue(element("events.art.viewer.use").waitForExistence(timeout: 15))
        element("events.art.viewer.use").click()
        XCTAssertTrue(element("events.art.viewer").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("events.art.panel.used").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("events.art.line")), "“Quiet Lantern”")
    }

    func testFullScreenShowsOnlyTheImageAndAPill() {
        app.launch(debugScene: "ev-full")
        XCTAssertTrue(element("events.art.viewer.hud").waitForExistence(timeout: 15))
        XCTAssertFalse(element("events.art.viewer.close").exists)
        XCTAssertFalse(element("events.art.viewer.film").exists)
        attach("ev-full")
        element("events.art.viewer.hud.next").click()
        let second = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "2 of 3", "2 of 3")
        XCTAssertTrue(element("events.art.viewer.hud").descendants(matching: .any).matching(second).firstMatch.waitForExistence(timeout: 5))
        element("events.art.viewer.hud.exit").click()
        XCTAssertTrue(element("events.art.viewer.close").waitForExistence(timeout: 5))
        XCTAssertFalse(element("events.art.viewer.hud").exists)
    }

    func testTheMovingVersionPlaysInTheViewer() {
        app.launch(debugScene: "ev-view-motion")
        XCTAssertTrue(element("events.art.viewer.motion").waitForExistence(timeout: 30))
        XCTAssertTrue(element("events.art.viewer.loop").exists)
        XCTAssertTrue(text(of: element("events.art.viewer.subtitle")).hasSuffix("moving version, 20 s loop"))
        attach("ev-view-motion")
    }

    /// The person's own files open full size with where the text goes.
    func testChosenFilesOpenFullSizeWithTheTextArea() {
        app.launch(debugScene: "ea-files")
        XCTAssertTrue(element("events.art.viewer").waitForExistence(timeout: 15))
        XCTAssertTrue(element("events.art.textAreaShown").exists)
        XCTAssertTrue(text(of: element("events.art.viewer.subtitle")).contains("Your files"))
        attach("ea-files")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The element's text once it shows.
    private func waitForText(in element: XCUIElement, timeout: TimeInterval = 5) -> String {
        _ = element.waitForExistence(timeout: timeout)
        return text(of: element)
    }

    private func waitForText(_ prefix: String, prefixOf element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        waitUntil(timeout) { element.exists && self.text(of: element).hasPrefix(prefix) }
    }

    private func waitForText(_ part: String, containedIn element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        waitUntil(timeout) { element.exists && self.text(of: element).contains(part) }
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
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
