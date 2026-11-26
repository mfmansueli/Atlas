//
//  AppInformationPageStripUITests.swift
//  AtlasUITests
//

import XCTest

/// App Information's top and page strip (board 88), driven through DEBUG
/// scenes (sample data, simulated App Store Connect; nothing leaves the
/// Mac): opening a page from its card, Accept n on This Page, and Accept
/// All Pages leaving every card Ready. Cards are
/// `appInformation.page.<page>`; their label is "General, 3 suggested".
@MainActor
final class AppInformationPageStripUITests: XCTestCase {
    private var app: XCUIApplication!

    /// The strip's order.
    private let pages = ["general", "appCompliance", "ageRating", "accessibility", "appPrivacy", "appReview", "exportCompliance"]

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testACardOpensItsPageAndIsTheSelectedOne() {
        app.launch(debugScene: "info-general")
        XCTAssertTrue(element("appInformation.general").waitForExistence(timeout: 10))
        XCTAssertTrue(card("general").isSelected)
        for page in pages {
            XCTAssertTrue(card(page).exists, "\(page) has a card")
        }

        open("ageRating")
        XCTAssertTrue(element("appInformation.ageRating").waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.card("ageRating").isSelected })
        XCTAssertFalse(card("general").isSelected)

        open("appReview")
        XCTAssertTrue(element("appInformation.appReview").waitForExistence(timeout: 5))
        XCTAssertTrue(card("appReview").isHittable, "The strip scrolled to the open card.")
    }

    func testAcceptOnThisPageLeavesThePageReady() {
        app.launch(debugScene: "in-general")
        let general = card("general")
        XCTAssertTrue(general.waitForExistence(timeout: 10))
        XCTAssertTrue(says(general, "3 suggested"), general.label)
        XCTAssertTrue(text(of: element("appInformation.estimate")).contains("suggestions"))

        let acceptHere = app.buttons["appInformation.acceptHere"]
        XCTAssertTrue(acceptHere.waitForExistence(timeout: 5))
        XCTAssertEqual(acceptHere.label, "Accept 3 on This Page")
        acceptHere.click()
        XCTAssertTrue(text(of: element("toast.text")).hasPrefix("Accepted 3 on General."))
        XCTAssertTrue(says(general, "Ready"), general.label)
        XCTAssertFalse(acceptHere.exists, "Nothing is left on this page.")
    }

    func testAcceptAllPagesLeavesEveryPageReady() {
        app.launch(debugScene: "info-accept-all")
        let acceptAll = app.buttons["appInformation.acceptAll"]
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil { acceptAll.isEnabled })
        XCTAssertTrue(says(card("general"), "suggested"), card("general").label)

        acceptAll.click()
        // Accept All shows the suggestions first, unless asked not to.
        let sheet = element("acceptAll.sheet")
        if sheet.waitForExistence(timeout: 3) {
            app.buttons["acceptAll.accept"].click()
            XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        }

        for page in pages {
            XCTAssertTrue(says(card(page), "Ready"), "\(page): \(card(page).label)")
        }
        XCTAssertEqual(text(of: element("appInformation.estimate")), "No suggestions waiting")
        XCTAssertFalse(acceptAll.isEnabled)
    }

    // MARK: - Helpers

    private func card(_ page: String) -> XCUIElement {
        element("appInformation.page.\(page)")
    }

    /// Clicks a page's card, scrolling the strip on first when the card is
    /// past its right edge.
    private func open(_ page: String) {
        let target = card(page)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let more = app.buttons["appInformation.page.more"]
        if !target.isHittable, more.exists { more.click() }
        XCTAssertTrue(waitUntil { target.isHittable })
        target.click()
    }

    private func says(_ card: XCUIElement, _ status: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", status)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: card)], timeout: 5) == .completed
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A SwiftUI `Text` exposes its string as its value on macOS, not its
    /// label.
    private func text(of element: XCUIElement) -> String {
        guard element.waitForExistence(timeout: 5) else { return "" }
        return (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
}
