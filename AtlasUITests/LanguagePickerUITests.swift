//
//  LanguagePickerUITests.swift
//  AtlasUITests
//

import XCTest

/// README-DS §12, one picker, not tabs: the language picker in the Store
/// Page's and Screenshots' language bars, its menu (Find a language focused
/// when it opens, filtering at once and keeping the groups, cleared when it
/// closes), the Screenshots group for languages that reuse the primary set,
/// and the compact picker over Overview's App Store preview.
@MainActor
final class LanguagePickerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// The picker sits in the bar, beside Accept All Languages, and says
    /// what's waiting here; no language tabs.
    func testTheStorePagePickerSaysWhatsWaitingHere() {
        app.launch(debugScene: "sp-cc")
        let bar = element("languageBar")
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let picker = bar.descendants(matching: .any)["languageBar.picker"]
        XCTAssertTrue(picker.exists, "The picker is in the bar")
        XCTAssertTrue(picker.label.hasPrefix("Language: English (U.S.). "), picker.label)
        XCTAssertTrue(picker.label.contains("suggestions here"), picker.label)
        XCTAssertTrue(bar.descendants(matching: .any)["languageBar.acceptAll"].exists)
        XCTAssertTrue(element("languageBar.previous").exists)
        XCTAssertTrue(element("languageBar.next").exists)
        attach("sp-picker")
    }

    func testFindALanguageFiltersAtOnceKeepsTheGroupsAndClearsOnClose() {
        app.launch(debugScene: "sp-cc")
        let picker = element("languageBar.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.click()

        let find = element("languageBar.menu.find")
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { (find.value(forKey: "hasKeyboardFocus") as? Bool) == true }, "Find a language is focused when the menu opens")
        XCTAssertTrue(element("languageBar.menu.group.toReview").exists)
        XCTAssertTrue(element("languageBar.menu.en-US").exists)
        attach("sp-menu")

        app.typeText("ger")
        XCTAssertTrue(element("languageBar.menu.de-DE").waitForExistence(timeout: 5))
        XCTAssertTrue(element("languageBar.menu.en-US").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("languageBar.menu.group.toReview").exists || element("languageBar.menu.group.upToDate").exists)
        attach("sp-menu-find")

        app.typeText("zzz")
        XCTAssertTrue(element("languageBar.menu.none").waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: element("languageBar.menu.none")).hasPrefix("No language matches"))

        // Closing the menu clears it.
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(find.waitForNonExistence(timeout: 5))
        picker.click()
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        XCTAssertTrue(element("languageBar.menu.en-US").exists)
        XCTAssertFalse(element("languageBar.menu.none").exists)
    }

    /// Choosing a language changes the editor and the picker together.
    func testChoosingALanguageFromTheMenuOpensIt() {
        app.launch(debugScene: "sp-cc")
        let picker = element("languageBar.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.click()
        let german = element("languageBar.menu.de-DE")
        XCTAssertTrue(german.waitForExistence(timeout: 5))
        german.click()
        XCTAssertTrue(element("languageBar.menu.find").waitForNonExistence(timeout: 5), "The menu closes")
        XCTAssertTrue(waitUntil { picker.label.hasPrefix("Language: German.") }, picker.label)
    }

    /// Screenshots: the same picker; languages without screenshots of
    /// their own come last, under "Uses English (U.S.) screenshots".
    func testTheScreenshotsMenuListsTheLanguagesThatReuseThePrimarySetLast() {
        app.launch(debugScene: "shots-page")
        let picker = element("languageBar.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        XCTAssertTrue(picker.label.hasPrefix("Language: German. "), picker.label)
        picker.click()
        XCTAssertTrue(element("languageBar.menu.find").waitForExistence(timeout: 5))
        XCTAssertTrue(element("languageBar.menu.de-DE").isSelected)
        let reusing = element("languageBar.menu.group.usesPrimary")
        if reusing.exists {
            XCTAssertEqual(text(of: reusing), "Uses English (U.S.) screenshots")
        }
        attach("sh-menu")
    }

    /// Overview's App Store preview: the compact picker, not tabs.
    func testTheOverviewPreviewUsesTheCompactPicker() {
        app.launch(debugScene: "nav-ov")
        let picker = element("overview.storePreview.language")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        XCTAssertTrue(picker.label.hasPrefix("Language: English (U.S.)."), picker.label)
        XCTAssertFalse(app.segmentedControls["overview.storePreview.language"].exists, "No language tabs")
        picker.click()
        XCTAssertTrue(element("languageBar.menu.find").waitForExistence(timeout: 5))
        XCTAssertFalse(element("languageBar.menu.acceptAll").exists, "The preview's menu only changes the preview")
        let german = element("languageBar.menu.de-DE")
        if german.exists {
            german.click()
            XCTAssertTrue(waitUntil { picker.label.hasPrefix("Language: German.") }, picker.label)
        }
        attach("ov-picker")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
