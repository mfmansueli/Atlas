//
//  AppInformationUITests.swift
//  AtlasUITests
//

import XCTest

/// App Information, driven through the DEBUG scenes in
/// `AppInformationDebugScenes` (sample data, simulated App Store Connect;
/// nothing leaves the Mac).
@MainActor
final class AppInformationUITests: XCTestCase {
    private var app: XCUIApplication!
    private let lumen = "6450000001"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testThePageStripSwitchesPages() {
        launch(scene: "info-general")
        XCTAssertTrue(element("appInformation.general").waitForExistence(timeout: 10))
        openPage("ageRating")
        XCTAssertTrue(element("appInformation.ageRating").waitForExistence(timeout: 5))
        openPage("exportCompliance")
        XCTAssertTrue(element("appInformation.exportCompliance").waitForExistence(timeout: 5))
        openPage("appPrivacy")
        XCTAssertTrue(element("appInformation.appPrivacy.notASync").waitForExistence(timeout: 5))
        // App Privacy has its own columns, under the same top and strip.
        XCTAssertTrue(element("appInformation.top").exists)
        XCTAssertTrue(element("appInformation.page").exists)
    }

    func testEditingCopyrightQueuesAChange() {
        launch(scene: "info-general")
        let copyright = app.textFields["appInformation.general.copyright"]
        XCTAssertTrue(copyright.waitForExistence(timeout: 10))
        copyright.click()
        copyright.typeKey("a", modifierFlags: .command)
        copyright.typeText("© 2027 Northpier Studio")
        app.buttons["workspace.reviewPushButton"].click()
        XCTAssertTrue(element("review.row.appInformation.\(lumen).general.lumen-v14.copyright").waitForExistence(timeout: 5))
    }

    /// Games as the secondary category brings its own two subcategory
    /// pickers under it; picking one queues the secondary pair.
    func testGamesAsTheSecondaryCategoryTakesItsOwnSubcategories() {
        launch(scene: "info-general")
        let secondary = app.popUpButtons["appInformation.general.secondaryCategory"]
        XCTAssertTrue(secondary.waitForExistence(timeout: 10))
        XCTAssertFalse(app.popUpButtons["appInformation.general.secondaryGamesSubcategory1"].exists)
        secondary.click()
        app.menuItems["Games"].click()
        let first = app.popUpButtons["appInformation.general.secondaryGamesSubcategory1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertFalse(app.popUpButtons["appInformation.general.gamesSubcategory1"].exists, "The primary category isn't Games.")
        reveal(first)
        first.click()
        app.menuItems["Word"].click()
        app.buttons["workspace.reviewPushButton"].click()
        XCTAssertTrue(element("review.row.appInformation.\(lumen).general.secondaryGamesSubcategories").waitForExistence(timeout: 5))
    }

    func testDeclaringForAppleWatchInTheEditor() {
        launch(scene: "a11y-published")
        let declare = app.buttons["appInformation.accessibility.APPLE_WATCH.declare"]
        XCTAssertTrue(declare.waitForExistence(timeout: 10))
        reveal(declare)
        declare.click()
        XCTAssertTrue(element("appInformation.accessibility.editor").waitForExistence(timeout: 5))
        element("appInformation.accessibility.editor.supportsAny").radioButtons["Yes"].click()
        XCTAssertFalse(element("appInformation.accessibility.editor.voiceControl").exists)
        XCTAssertTrue(element("appInformation.accessibility.editor.hidden").exists)
        app.checkBoxes["appInformation.accessibility.editor.voiceOver"].click()
        app.buttons["appInformation.accessibility.editor.save"].click()
        XCTAssertTrue(element("appInformation.accessibility.editor").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("appInformation.toast").waitForExistence(timeout: 5))
        XCTAssertTrue(element("appInformation.accessibility.APPLE_WATCH.notPushed").exists)
    }

    func testCopyFromIPhoneSaysWhatWasLeftOut() {
        launch(scene: "a11y-published")
        let copy = app.buttons["appInformation.accessibility.APPLE_WATCH.copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        reveal(copy)
        copy.click()
        let toast = element("appInformation.toast")
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "Voice Control isn’t available there").exists)
    }

    func testThePublishSwitchInReview() {
        launch(scene: "a11y-review")
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 10))
        let iPhone = element("review.option.appInformation.\(lumen).accessibility.IPHONE")
        let vision = element("review.option.appInformation.\(lumen).accessibility.VISION")
        XCTAssertTrue(iPhone.exists)
        XCTAssertFalse(vision.isEnabled)
        XCTAssertTrue(text(containing: "2 declarations go live when pushed").exists)
        iPhone.click()
        XCTAssertTrue(text(containing: "1 declaration goes live when pushed").waitForExistence(timeout: 5))
    }

    func testAnAccessibilityErrorOffersTryAgain() {
        launch(scene: "a11y-error")
        XCTAssertTrue(element("appInformation.accessibility.error").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["appInformation.accessibility.retry"].exists)
    }

    func testAnAssistantsAnswerShowsItsEvidence() {
        launch(scene: "info-age")
        let evidence = element("appInformation.age.wellness.evidence")
        XCTAssertTrue(evidence.waitForExistence(timeout: 10))
        evidence.click()
        XCTAssertTrue(app.buttons["appInformation.evidence.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appInformation.evidence.reject"].exists)
    }

    func testConfirmAllConfirmsEveryAssistantAnswer() {
        launch(scene: "info-age")
        let confirmAll = app.buttons["appInformation.age.confirmAll"]
        XCTAssertTrue(confirmAll.waitForExistence(timeout: 10))
        let wellness = app.checkBoxes["appInformation.age.wellness.confirmed"]
        XCTAssertTrue(wellness.exists)
        confirmAll.click()
        XCTAssertTrue(text(containing: "all confirmed").waitForExistence(timeout: 5))
        XCTAssertFalse(confirmAll.exists, "Nothing is left to confirm.")
        XCTAssertEqual(wellness.value as? Int, 1)
    }

    /// Claude Code's Sign-in required shows under its switch, and the
    /// suggested demo user name shows its row even before sign-in is on.
    func testSuggestedSignInAndUserNameShowUnderTheirFields() {
        launch(scene: "info-signin-suggested")
        let signIn = element("appInformation.suggestions.demoAccountRequired")
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        let userName = element("appInformation.suggestions.demoAccountName")
        XCTAssertTrue(userName.exists)
        XCTAssertFalse(text(containing: "lumen-sandbox").exists, "No password is suggested.")
        reveal(signIn)
        let accept = signIn.descendants(matching: .any)["suggestion.accept"].firstMatch
        accept.click()
        // The row stays, saying who suggested the value, with Undo.
        XCTAssertTrue(waitUntil { !accept.exists })
        let toggle = element("appInformation.review.signInRequired")
        XCTAssertEqual(toggle.value as? Int, 1)
    }

    /// The German User Privacy Choices URL Claude Code suggests shows
    /// under that language's field on App Privacy's Privacy URLs.
    func testSuggestedPrivacyChoicesURLShowsUnderItsLanguage() {
        launch(scene: "info-choices-suggested")
        let card = element("appInformation.suggestions.appPrivacy.de-DE.privacyChoicesUrl")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertTrue(text(containing: "https://lumen.example/de/privacy/choices").exists)
        reveal(card)
        let accept = card.descendants(matching: .any)["suggestion.accept"].firstMatch
        accept.click()
        XCTAssertTrue(waitUntil { !accept.exists })
    }

    /// Privacy URLs says the answers are never in its suggestions; Accept
    /// 1 on This Page, at the top, takes the German URL.
    func testAppPrivacysBarAcceptsItsURLSuggestions() {
        launch(scene: "info-choices-suggested")
        let urls = element("appInformation.appPrivacy.urls")
        XCTAssertTrue(urls.waitForExistence(timeout: 15))
        let bar = urls.descendants(matching: .any)["appInformation.appPrivacy.suggestionBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(element("appInformation.appPrivacy.barNote").exists)
        let card = element("appInformation.suggestions.appPrivacy.de-DE.privacyChoicesUrl")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let acceptHere = app.buttons["appInformation.acceptHere"]
        XCTAssertTrue(acceptHere.exists)
        acceptHere.click()
        XCTAssertTrue(waitUntil { !card.descendants(matching: .any)["suggestion.accept"].firstMatch.exists })
        // Accept n on This Page says it with the shared toast (board 88).
        XCTAssertTrue(element("toast.text").waitForExistence(timeout: 5) || element("appInformation.toast").exists)
    }

    /// The bar's arrows go to the language with a suggestion and say which.
    func testAppPrivacysArrowsGoToTheLanguageWithASuggestion() {
        launch(scene: "info-choices-suggested")
        let next = app.buttons["appInformation.appPrivacy.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.click()
        let position = element("appInformation.appPrivacy.position")
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "German, 1 of 1").exists)
        XCTAssertTrue(element("appInformation.suggestions.appPrivacy.de-DE.privacyChoicesUrl").isHittable)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
    }

    /// Ignores saved window state, which can leave the app without a
    /// window under XCUITest.
    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    /// The page bar and the suggestions above it push the lower cards to
    /// the window's bottom edge, where a click lands outside the window:
    /// the page scrolls until `target` is fully in view.
    private func reveal(_ target: XCUIElement) {
        let page = element("appInformation.pageContent")
        guard page.exists else { return }
        var tries = 0
        while tries < 12 {
            if target.frame.minY >= page.frame.minY, target.frame.maxY <= page.frame.maxY - 8 { return }
            page.scroll(byDeltaX: 0, deltaY: target.frame.minY < page.frame.minY ? 200 : -200)
            tries += 1
        }
    }

    /// Clicks a page's card in the strip, scrolling the strip on first
    /// when the card is past its right edge.
    private func openPage(_ page: String) {
        let card = element("appInformation.page.\(page)")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let more = app.buttons["appInformation.page.more"]
        if !card.isHittable, more.exists { more.click() }
        card.click()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A SwiftUI `Text` exposes its string as its value on macOS, not its
    /// label.
    private func text(containing string: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", string, string))
            .firstMatch
    }
}
