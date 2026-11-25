//
//  PricingUITests.swift
//  AtlasUITests
//

import XCTest

/// Subscription Pricing's mode, strategy and a product's Prices by Country
/// (board 73), driven through the DEBUG scenes in `PricingDebugScenes` and
/// `PricesByCountryPageDebugScenes` (sample prices and price points,
/// simulated App Store Connect; nothing leaves the Mac).
@MainActor
final class PricingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testChoosingAModeInTheFirstVisitSheet() {
        launch(scene: "mode-sheet")
        XCTAssertTrue(element("pricing.modeSheet").waitForExistence(timeout: 10))
        element("pricing.modeSheet.option.showSuggestions").click()
        app.buttons["pricing.modeSheet.continue"].click()
        XCTAssertTrue(element("pricing.modeSheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "pricing.card.accept").firstMatch.waitForExistence(timeout: 20))
    }

    /// Accept All N… asks once (risk level 3), then the prices wait in
    /// Review & Push.
    func testAcceptAllAddsThePricesToReviewAndPush() {
        launch(scene: "pr-prod-acc")
        let sheet = element("countries.acceptAll")
        XCTAssertTrue(sheet.waitForExistence(timeout: 20))
        XCTAssertTrue(app.checkBoxes["countries.acceptAll.keep"].exists)
        let before = reviewCount()
        app.buttons["countries.acceptAll.add"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        let queued = NSPredicate { _, _ in self.reviewCount() > before }
        wait(for: [XCTNSPredicateExpectation(predicate: queued, object: app)], timeout: 10)
    }

    /// Turning off Keep their current price shows the amber note.
    func testRaisingPricesForEveryoneWarns() {
        launch(scene: "pr-prod-acc")
        XCTAssertTrue(element("countries.acceptAll").waitForExistence(timeout: 20))
        XCTAssertFalse(element("countries.acceptAll.consent").exists)
        app.checkBoxes["countries.acceptAll.keep"].click()
        XCTAssertTrue(element("countries.acceptAll.consent").waitForExistence(timeout: 5))
    }

    func testKeepPricesHasNoBannerAndKeepsTheStrategy() {
        launch(scene: "pr-prod-keep")
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 20))
        XCTAssertFalse(element("countries.banner").exists)
        XCTAssertTrue(element("countries.strategy").exists)
        XCTAssertEqual(elements(prefixed: "countries.accept.").count, 0)
    }

    /// The popover on a suggestion says why, and Accept takes its price.
    func testASuggestionOpensWhy() {
        launch(scene: "pr-prod-why")
        let popover = element("countries.popover")
        XCTAssertTrue(popover.waitForExistence(timeout: 20))
        XCTAssertTrue(element("countries.popover.why").exists)
        XCTAssertTrue(app.buttons["countries.popover.set"].label.hasPrefix("Accept "))
        let before = reviewCount()
        app.buttons["countries.popover.set"].click()
        XCTAssertTrue(popover.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("toast.undo").waitForExistence(timeout: 5))
        XCTAssertGreaterThan(reviewCount(), before)
    }

    func testFiltersSayWhatTheyKeep() {
        launch(scene: "pr-prod-filters")
        let line = element("countries.filterLine.text")
        XCTAssertTrue(line.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: line).hasPrefix("Europe · Increases only · "), text(of: line))
        app.typeKey(.escape, modifierFlags: [])
        element("countries.filterLine.clear").click()
        XCTAssertTrue(element("countries.filterLine").waitForNonExistence(timeout: 5))
    }

    /// ⌘R, and the refresh after a push, show the skeleton until the
    /// prices are back; that once crashed AppKit's layout.
    func testRefreshShowsTheSkeletonThenThePrices() {
        launch(scene: "pricing-refresh")
        XCTAssertTrue(element("countries.skeleton").waitForExistence(timeout: 10))
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 10))
        XCTAssertFalse(element("countries.skeleton").exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Helpers

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func elements(prefixed prefix: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    /// A text element's string: its value on macOS, else its label.
    private func text(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty { return value }
        return element.label
    }

    /// The number on Review & Push, from "N changes ready" (0 when Up to date).
    private func reviewCount() -> Int {
        let value = app.buttons["workspace.reviewPushButton"].value as? String ?? ""
        return Int(value.prefix { $0.isNumber }) ?? 0
    }
}
