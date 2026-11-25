//
//  ScreenshotsAllLanguagesUITests.swift
//  AtlasUITests
//

import XCTest

/// All Languages on the Screenshots language page (`shots-page-all`): a
/// strip of each language's own screenshots under its row, and clicking
/// the row opens the language.
@MainActor
final class ScreenshotsAllLanguagesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func testRowsShowTheirScreenshotsAndOpenTheLanguage() {
        app.launch(debugScene: "shots-page-all")
        let list = element("screenshots.page.allLanguages")
        XCTAssertTrue(list.waitForExistence(timeout: 20))
        let english = element("screenshots.page.language.en-US")
        XCTAssertTrue(english.exists)
        // VoiceOver reads the name, the state and how many screenshots.
        XCTAssertTrue(english.label.hasPrefix("English (U.S.), "), english.label)
        XCTAssertTrue(english.label.hasSuffix(" screenshots"), english.label)
        let german = element("screenshots.page.language.de-DE")
        XCTAssertTrue(german.label.hasPrefix("German, 3 captions suggested"), german.label)

        german.click()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: list)
        waitForExpectations(timeout: 5)
    }
}
