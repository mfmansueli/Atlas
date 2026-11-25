//
//  ProductPagesUITests.swift
//  AtlasUITests
//

import XCTest

/// Custom Product Pages (⌘4) in its DEBUG scenes (boards 50–55, Lumen
/// Journal's sample pages; nothing reaches Apple): the list and its states,
/// suggested pages, New Page…, the editor in several languages, Submit for
/// Review and the status banners, the confirmations, and the ways in from
/// the Overview and Analytics.
@MainActor
final class ProductPagesUITests: XCTestCase {
    private var app: XCUIApplication!

    private static let prompts = "45812c9b-7d1e-4f0a-9c3b-2e61a0b8d4f7"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Board 50: the list

    func testTheListShowsTheDefaultPageFirstThenEachPage() {
        app.launch(debugScene: "cp")
        XCTAssertTrue(element("pages.table").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.row.default").exists)
        XCTAssertTrue(text(of: element("pages.count")).hasPrefix("6 of 70"), text(of: element("pages.count")))
        let prompts = element("pages.row.\(Self.prompts)")
        XCTAssertTrue(prompts.exists)
        XCTAssertTrue(element("pages.copy.\(Self.prompts)").exists)
        XCTAssertTrue(element("pages.suggestion.weekly").exists)
        XCTAssertTrue(element("pages.suggestion.grat").exists)
        attach("cp")
        prompts.click()
        XCTAssertTrue(element("pages.editor.name").waitForExistence(timeout: 10))
        element("pages.editor.back").click()
        XCTAssertTrue(element("pages.table").waitForExistence(timeout: 10))
    }

    func testAcceptingASuggestedPageMakesADraft() {
        app.launch(debugScene: "cp-sug")
        XCTAssertTrue(element("pages.suggestion.weekly.details").waitForExistence(timeout: 15))
        attach("cp-sug")
        element("pages.suggestion.weekly.accept").click()
        XCTAssertTrue(row(named: "Weekly reflections").waitForExistence(timeout: 10))
        XCTAssertFalse(element("pages.suggestion.weekly").exists)
    }

    func testASuggestedPageShowsTheTextAtlasStopped() {
        app.launch(debugScene: "cp")
        let notOffered = element("pages.suggestion.grat.notOffered")
        XCTAssertTrue(notOffered.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: notOffered).localizedCaseInsensitiveContains("not offered"), text(of: notOffered))
        element("pages.suggestion.grat.show").click()
        XCTAssertTrue(element("pages.refused.de-DE").waitForExistence(timeout: 10))
        attach("cp-grat-refused")
    }

    func testNoPagesOffersTheFirstOne() {
        app.launch(debugScene: "cp-empty")
        // Board 74: the empty state explains; New Page… stays at the top.
        XCTAssertTrue(element("pages.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["No custom product pages yet"].exists)
        XCTAssertFalse(element("pages.empty.new").exists, "No second New Page… in the middle")
        let create = element("pages.new")
        XCTAssertTrue(create.isEnabled)
        attach("cp-empty")
        create.click()
        XCTAssertTrue(element("pages.newSheet").waitForExistence(timeout: 10))
    }

    func testTheListsStates() {
        app.launch(debugScene: "cp-limit")
        XCTAssertTrue(element("pages.banner.limit").waitForExistence(timeout: 15))
        XCTAssertFalse(element("pages.new").isEnabled)
        attach("cp-limit")
        app.terminate()

        app.launch(debugScene: "cp-loading")
        XCTAssertTrue(element("pages.loading").waitForExistence(timeout: 15))
        app.terminate()

        app.launch(debugScene: "cp-offline")
        XCTAssertTrue(element("pages.banner.offline").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.table").exists)
        app.terminate()

        app.launch(debugScene: "cp-norole")
        XCTAssertTrue(element("pages.banner.norole").waitForExistence(timeout: 15))
        XCTAssertFalse(element("pages.new").isEnabled)
        attach("cp-norole")
    }

    // MARK: - Board 51: New Page and the editor

    func testNewPageMakesADraftAndOpensIt() {
        app.launch(debugScene: "cp-new")
        let name = element("pages.new.name")
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        XCTAssertFalse(element("pages.new.create").isEnabled)
        name.click()
        name.typeText("Spring campaign")
        attach("cp-new")
        element("pages.new.create").click()
        XCTAssertTrue(element("pages.editor.name").waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: element("pages.editor.name")).contains("Spring campaign"))
    }

    func testANewCopyNamesThePageItCopies() {
        app.launch(debugScene: "cp-new-copy")
        XCTAssertTrue(element("pages.new.copyFrom").waitForExistence(timeout: 15))
        attach("cp-new-copy")
    }

    func testTheEditorShowsEachPartOfThePage() {
        app.launch(debugScene: "cp-edit")
        XCTAssertTrue(element("pages.editor.name").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.linkCard").exists)
        XCTAssertTrue(element("languageBar.picker").exists, "One language picker, not a chip per language")
        XCTAssertTrue(text(of: element("pages.promo.counter")).contains("/ 170"))
        XCTAssertTrue(element("pages.keywordsBox").exists)
        XCTAssertEqual(element("pages.editor.submit").label, "Submit for Review…")
        attach("cp-edit")
        scrollTo(element("pages.screenshotsBox"))
        XCTAssertTrue(element("pages.screenshotsBox").exists)
    }

    func testAGermanSuggestionCanBeAccepted() {
        app.launch(debugScene: "cp-edit-de")
        let suggestion = element("pages.textSuggestion")
        XCTAssertTrue(suggestion.waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.textSuggestion.evidence").exists)
        attach("cp-edit-de")
        element("pages.textSuggestion.accept").click()
        XCTAssertTrue(waitForGone(suggestion))
    }

    func testATextAtlasStoppedOffersTheRulesAndAnother() {
        app.launch(debugScene: "cp-edit-refused")
        XCTAssertTrue(element("pages.refused.en-US").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.refused.rules").exists)
        XCTAssertTrue(element("pages.refused.ask").exists)
        XCTAssertFalse(element("pages.textSuggestion.accept").exists)
        attach("cp-edit-refused")
    }

    func testTheEditorsOtherLanguagesAndStates() {
        app.launch(debugScene: "cp-edit-fr")
        XCTAssertTrue(element("pages.promo.empty").waitForExistence(timeout: 15))
        attach("cp-edit-fr")
        app.terminate()

        app.launch(debugScene: "cp-edit-noversion")
        XCTAssertTrue(element("pages.keywords.noVersion").waitForExistence(timeout: 15))
        attach("cp-edit-noversion")
        app.terminate()

        app.launch(debugScene: "cp-edit-ar")
        XCTAssertTrue(element("pages.promo").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.deepLink").exists)
        attach("cp-edit-ar")
        app.terminate()

        app.launch(debugScene: "cp-edit-deeplink")
        XCTAssertTrue(element("pages.deepLink.check").waitForExistence(timeout: 15))
        attach("cp-edit-deeplink")
    }

    func testMovingAKeywordAsksFirst() {
        app.launch(debugScene: "cp-kwmove")
        let move = app.buttons["Move Keyword"]
        XCTAssertTrue(move.waitForExistence(timeout: 15))
        attach("cp-kwmove")
        move.click()
        XCTAssertTrue(waitForGone(move))
    }

    // MARK: - Board 54: submitting and where it stands

    func testSubmittingSendsThePageAndSaysItWaits() {
        app.launch(debugScene: "cp-submit")
        XCTAssertTrue(element("pages.submitSheet").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.submit.visible").exists)
        XCTAssertTrue(element("pages.submit.check.version").exists)
        attach("cp-submit")
        element("pages.submit.confirm").click()
        XCTAssertTrue(waitForGone(element("pages.submitSheet")))
        XCTAssertTrue(element("pages.status.cancel").waitForExistence(timeout: 10))
    }

    /// An accepted suggestion's brief under the screenshots, and at Submit
    /// the warning that a page with keywords still shows the default
    /// page's screenshots in search.
    func testAnAcceptedSuggestionsBriefShowsUnderTheScreenshotsAndAtSubmit() {
        app.launch(debugScene: "cp-edit-brief")
        XCTAssertTrue(element("pages.brief").waitForExistence(timeout: 15))
        let screens = text(of: element("pages.brief.screens"))
        XCTAssertTrue(screens.contains("Lock (“Locked with Face ID”)"), screens)
        // A draft: nothing in App Store Connect to open yet.
        XCTAssertFalse(element("pages.brief.open").exists)
        attach("cp-edit-brief")
        app.terminate()

        app.launch(debugScene: "cp-submit-brief")
        let check = element("pages.submit.check.screenshots")
        XCTAssertTrue(check.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: check).contains("The brief asks for: Lock"), text(of: check))
        attach("cp-submit-brief")
    }

    func testAWaitingPageCanBeCancelled() {
        app.launch(debugScene: "cp-waiting")
        let cancel = element("pages.status.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        attach("cp-waiting")
        cancel.click()
        XCTAssertTrue(waitForGone(cancel))
    }

    func testTheStatusBanners() {
        app.launch(debugScene: "cp-inreview")
        XCTAssertTrue(element("pages.status").waitForExistence(timeout: 15))
        XCTAssertFalse(element("pages.status.cancel").exists)
        app.terminate()

        app.launch(debugScene: "cp-rejected")
        XCTAssertTrue(element("pages.status.openASC").waitForExistence(timeout: 15))
        attach("cp-rejected")
        app.terminate()

        app.launch(debugScene: "cp-approved")
        let edit = element("pages.status.edit")
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        attach("cp-approved")
        edit.click()
        XCTAssertTrue(element("pages.compare").waitForExistence(timeout: 10))
        app.terminate()

        app.launch(debugScene: "cp-liveedit")
        XCTAssertTrue(element("pages.compare").waitForExistence(timeout: 15))
        attach("cp-liveedit")
    }

    // MARK: - Board 55: confirmations

    func testHideDeleteAndDiscardAskFirst() {
        app.launch(debugScene: "cp-hide")
        XCTAssertTrue(app.buttons["Hide Page"].waitForExistence(timeout: 15))
        attach("cp-hide")
        app.buttons["Hide Page"].click()
        XCTAssertTrue(waitForGone(app.buttons["Hide Page"]))
        app.terminate()

        app.launch(debugScene: "cp-delete")
        XCTAssertTrue(app.buttons["Delete Page"].waitForExistence(timeout: 15))
        attach("cp-delete")
        app.terminate()

        app.launch(debugScene: "cp-discard")
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 15))
        attach("cp-discard")
    }

    // MARK: - Ways in

    func testTheOverviewCardOpensThePages() {
        app.launch(debugScene: "cp-overview")
        let open = element("overview.afterRelease.open.productPages")
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        attach("cp-overview")
        open.click()
        XCTAssertTrue(element("pages.new").waitForExistence(timeout: 15))
    }

    func testAnalyticsOpensACustomPage() {
        app.launch(debugScene: "cp-analytics")
        let openPage = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "analytics.breakdown.openPage.")).firstMatch
        XCTAssertTrue(openPage.waitForExistence(timeout: 20))
        attach("cp-analytics")
        openPage.click()
        XCTAssertTrue(element("pages.editor.name").waitForExistence(timeout: 15))
    }

    /// At the smallest window each row takes two lines and nothing is cut.
    func testTheSmallestWindowKeepsEverything() {
        app.launch(debugScene: "cp-s")
        XCTAssertTrue(element("pages.table").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.copy.\(Self.prompts)").isHittable)
        attach("cp-s")
        app.terminate()

        app.launch(debugScene: "cp-edit-s")
        XCTAssertTrue(element("pages.editor.name").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pages.editor.submit").isHittable)
        attach("cp-edit-s")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A page's row in the list, by the name it shows.
    private func row(named name: String) -> XCUIElement {
        let row = NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "pages.row.", name)
        return app.descendants(matching: .any).matching(row).firstMatch
    }

    /// The editor scrolls: what's below the fold comes up.
    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            element("pages.editor.scroll").scroll(byDeltaX: 0, deltaY: -400)
        }
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if !element.exists { return true }
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
