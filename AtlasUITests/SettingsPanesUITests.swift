//
//  SettingsPanesUITests.swift
//  AtlasUITests
//

import XCTest

/// Board 48's Settings: the sidebar and its search, and the panes that are
/// new (Suggestions, Screenshots, Notifications, Atlas Pro, Privacy &
/// Data), each opened by its DEBUG scene. Nothing reaches Apple or the
/// Keychain, and Remove All Keys and Data… deletes nothing in a scene.
@MainActor
final class SettingsPanesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - The sidebar

    func testTheSidebarOpensEachPane() {
        app.launch(debugScene: "set-general")
        XCTAssertTrue(element("settings.pane.title").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("settings.pane.title")), "General")
        attach("set-general")
        element("settings.nav.notifications").click()
        XCTAssertTrue(waitForText("Notifications", in: element("settings.pane.title")))
        element("settings.nav.privacy").click()
        XCTAssertTrue(waitForText("Privacy & Data", in: element("settings.pane.title")))
    }

    func testSearchNarrowsThePanes() {
        app.launch(debugScene: "set-general")
        let search = app.textFields["settings.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.click()
        search.typeText("vendor")
        XCTAssertTrue(element("settings.nav.accounts").waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.nav.pricing").waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitForText("Accounts", in: element("settings.pane.title")))
        search.typeText("zzzz")
        XCTAssertTrue(element("settings.search.none").waitForExistence(timeout: 5))
    }

    func testAppearanceIsThreeChoices() {
        app.launch(debugScene: "set-general")
        let appearance = element("settings.appearance")
        XCTAssertTrue(appearance.waitForExistence(timeout: 15))
        XCTAssertEqual(appearance.radioButtons["Match System"].value as? Int, 1)
        appearance.radioButtons["Dark"].click()
        XCTAssertEqual(appearance.radioButtons["Dark"].value as? Int, 1)
        attach("set-general-dark")
        appearance.radioButtons["Match System"].click()
    }

    // MARK: - Accounts

    func testRemovalAskedInPlaceCanBeCancelled() {
        app.launch(debugScene: "set-accounts-remove")
        XCTAssertTrue(element("settings.remove.panel").waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: element("settings.remove.detail")).contains("Nothing changes in App Store Connect."))
        attach("set-accounts-remove")
        app.buttons["settings.remove.cancel"].click()
        XCTAssertTrue(element("settings.remove.panel").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("settings.key.Q7MZ3K8PLA").exists)
    }

    func testFreeSaysASecondAccountIsPro() {
        app.launch(debugScene: "set-free")
        // The sidebar's rows read as their titles.
        let accounts = element("settings.nav.accounts")
        XCTAssertTrue(accounts.waitForExistence(timeout: 15))
        accounts.click()
        XCTAssertTrue(element("settings.addKey.pro").waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.vendorNumber").exists)
    }

    // MARK: - AI Assistants

    func testAnAssistantShowsWhatItMayAndNeverMayDo() {
        app.launch(debugScene: "set-assistants")
        XCTAssertTrue(app.buttons["settings.source.assistant"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.source.assistant"].isSelected)
        XCTAssertTrue(element("settings.ai.assistants").exists)
        attach("set-assistants")
        XCTAssertTrue(scrollTo(element("settings.ai.cannot")))
        XCTAssertTrue(element("settings.ai.allow.artwork").exists)
        attach("set-assistants-permissions")
    }

    func testAnAPIKeyShowsTheProviderAndKey() {
        app.launch(debugScene: "set-assistants-key")
        XCTAssertTrue(app.secureTextFields["settings.apiKey"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.apiKey.check"].exists)
        XCTAssertFalse(element("settings.ai.assistants").exists)
        attach("set-assistants-key")
    }

    // MARK: - Suggestions and Screenshots

    func testSuggestionsChecksAndWhatIsNeverAccepted() {
        app.launch(debugScene: "set-suggestions")
        let repeated = app.switches["settings.checksRepeatedWords"]
        XCTAssertTrue(repeated.waitForExistence(timeout: 15))
        XCTAssertEqual(repeated.value as? Int, 1)
        XCTAssertEqual(app.switches["settings.asksBeforeAcceptAll"].value as? Int, 1)
        attach("set-suggestions")
        XCTAssertTrue(scrollTo(element("settings.neverAccepted")))
        attach("set-suggestions-never")
    }

    func testScreenshotsArtworkDefaults() {
        app.launch(debugScene: "set-shots")
        let words = app.switches["settings.artworkWords"]
        XCTAssertTrue(words.waitForExistence(timeout: 15))
        XCTAssertEqual(words.value as? Int, 0)
        XCTAssertEqual(app.switches["settings.artworkMotion"].value as? Int, 0)
        words.click()
        XCTAssertEqual(words.value as? Int, 1)
        attach("set-shots")
    }

    // MARK: - Notifications

    func testNotificationsAllowed() {
        app.launch(debugScene: "set-notif")
        XCTAssertTrue(element("settings.notif.allowed").waitForExistence(timeout: 15))
        XCTAssertEqual(app.switches["settings.notif.needsYou"].value as? Int, 1)
        XCTAssertEqual(app.switches["settings.notif.sound"].value as? Int, 0)
        XCTAssertTrue(element("settings.notif.newReviews").exists)
        attach("set-notif")
    }

    func testNotificationsBlockedSaysSo() {
        app.launch(debugScene: "set-notif-blocked")
        XCTAssertTrue(element("settings.notif.blocked").waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: element("settings.notif.permission")).hasPrefix("Notifications are turned off for Atlas"))
        XCTAssertTrue(app.buttons["settings.notif.openSystemSettings"].exists)
        attach("set-notif-blocked")
    }

    // MARK: - Atlas Pro

    func testProSaysThePlanAndWhenItRenews() {
        app.launch(debugScene: "set-pro")
        let plan = element("settings.pro.plan")
        XCTAssertTrue(plan.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForText("Atlas Pro · Yearly", in: plan))
        // The date is in the Mac's format: "November 2, 2027" or "2 November 2027".
        let detail = text(of: element("settings.pro.detail"))
        XCTAssertTrue(detail.hasPrefix("Renews ") && detail.contains("2027"), detail)
        XCTAssertTrue(detail.contains("$59.99 a year"), detail)
        XCTAssertTrue(app.buttons["settings.pro.manage"].exists)
        XCTAssertTrue(app.buttons["settings.pro.redeem"].exists)
        attach("set-pro")
    }

    func testFreeOpensThePlansInSettings() {
        app.launch(debugScene: "set-free")
        let see = app.buttons["settings.pro.seePlans"]
        XCTAssertTrue(see.waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("settings.pro.plan")), "Atlas Free")
        attach("set-free")
        see.click()
        XCTAssertTrue(element("paywall.title").waitForExistence(timeout: 10))
        app.buttons["paywall.close"].click()
        XCTAssertTrue(element("paywall.title").waitForNonExistence(timeout: 5))
    }

    // MARK: - Privacy & Data

    func testDontAskAgainChoicesReset() {
        app.launch(debugScene: "set-privacy")
        let reset = app.buttons["settings.privacy.resetConfirmations"]
        XCTAssertTrue(reset.waitForExistence(timeout: 15))
        XCTAssertTrue(anyText(containing: "3 confirmations are turned off.").waitForExistence(timeout: 5))
        attach("set-privacy")
        reset.click()
        XCTAssertTrue(anyText(containing: "Every confirmation is on.").waitForExistence(timeout: 5))
        XCTAssertFalse(reset.isEnabled)
    }

    func testActivityOpensAndRemoveAllAsksFirst() {
        app.launch(debugScene: "set-privacy")
        let show = app.buttons["settings.privacy.showActivity"]
        XCTAssertTrue(show.waitForExistence(timeout: 15))
        show.click()
        XCTAssertTrue(app.buttons["settings.privacy.activity.done"].waitForExistence(timeout: 5))
        attach("set-privacy-activity")
        app.buttons["settings.privacy.activity.done"].click()

        app.buttons["settings.privacy.removeAll"].click()
        let cancel = app.windows.descendants(matching: .button)["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        attach("set-privacy-remove")
        cancel.click()
        XCTAssertTrue(app.buttons["settings.privacy.removeAll"].exists)
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Any text on screen with these words, label or value.
    private func anyText(containing words: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)).firstMatch
    }

    private func waitForText(_ expected: String, in element: XCUIElement, contains: Bool = false) -> Bool {
        let predicate = NSPredicate { _, _ in
            let text = self.text(of: element)
            return contains ? text.contains(expected) : text == expected
        }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5) == .completed
    }

    /// Scrolls the pane until the element is on screen (Form rows below the
    /// fold aren't hittable).
    private func scrollTo(_ element: XCUIElement) -> Bool {
        for _ in 0..<8 {
            if element.exists, element.isHittable { return true }
            app.windows.firstMatch.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        }
        return element.exists
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
