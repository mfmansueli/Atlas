//
//  PricesByCountryUITests.swift
//  AtlasUITests
//

import XCTest

/// A product's Prices by Country (board 73) on Lumen's fixtures: the price
/// popover, setting a price, Undo, and the bar for selected countries.
@MainActor
final class PricesByCountryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    func testThePricePopoverOpensFromThePrice() {
        app.launch(debugScene: "pr-prod-find")
        let price = element("countries.price.DEU")
        XCTAssertTrue(price.waitForExistence(timeout: 15))
        price.click()
        let popover = element("countries.popover")
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
        XCTAssertTrue(element("countries.popover.automatic").exists)
        XCTAssertTrue(element("countries.popover.chosen").exists)
        element("countries.popover.cancel").click()
        XCTAssertTrue(popover.waitForNonExistence(timeout: 5))
    }

    func testSettingAPriceWaitsAndUndoTakesItBack() {
        app.launch(debugScene: "pr-prod-edit")
        let set = element("countries.popover.set")
        XCTAssertTrue(set.waitForExistence(timeout: 15))
        XCTAssertTrue(set.isEnabled)
        set.click()

        let undo = element("countries.undo.BRA")
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Not pushed"].firstMatch.exists)
        undo.click()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("countries.accept.BRA").waitForExistence(timeout: 5))
    }

    func testTheToastsUndoTakesThePriceBack() {
        app.launch(debugScene: "pr-prod-set")
        let undoInRow = element("countries.undo.BRA")
        XCTAssertTrue(undoInRow.waitForExistence(timeout: 15))
        XCTAssertTrue(element("toast.text").label.hasPrefix("Brazil: "))
        let toastUndo = element("toast.undo")
        XCTAssertTrue(toastUndo.exists)
        toastUndo.click()
        XCTAssertTrue(undoInRow.waitForNonExistence(timeout: 5))
    }

    func testSelectedCountriesShowTheBar() {
        app.launch(debugScene: "pr-prod-sel")
        let bar = element("countries.bulk")
        XCTAssertTrue(bar.waitForExistence(timeout: 15))
        XCTAssertEqual(element("countries.bulk.count").label, "3 selected")
        XCTAssertTrue(element("countries.bulk.accept").exists)
        element("countries.bulk.deselect").click()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5))
    }

    /// Find that matches nothing says so, and Clear Search brings the
    /// countries back (board 74).
    func testFindWithNoResultsClearsTheSearch() {
        app.launch(debugScene: "es-find")
        let clear = element("countries.empty.clearSearch")
        XCTAssertTrue(clear.waitForExistence(timeout: 15))
        clear.click()
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 5))
    }

    /// Suggested with nothing left to suggest says what that means, and
    /// the footer counts the countries.
    func testAnEmptyFilterSaysWhy() {
        app.launch(debugScene: "pr-prod-none")
        let empty = element("countries.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        XCTAssertTrue(empty.label.contains("No suggested prices left"), empty.label)
        XCTAssertTrue(element("countries.footer.totals").exists)
    }
}
