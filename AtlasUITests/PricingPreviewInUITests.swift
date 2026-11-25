//
//  PricingPreviewInUITests.swift
//  AtlasUITests
//

import XCTest

/// "Preview in" beside Pricing's product cards: the country pop-up with
/// Find a country or currency, countries with price changes first, and ‹ ›
/// through the countries with a change; each product shows its price there.
@MainActor
final class PricingPreviewInUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Brazil: Annual's price waits in Review & Push, Monthly's is
    /// suggested; each product shows its price there.
    func testBrazilShowsWhatChanges() {
        app.launch(debugScene: "pr-prev")
        let picker = element("pricing.preview.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        XCTAssertTrue(picker.label.hasPrefix("Country: Brazil."), picker.label)
        XCTAssertTrue(waitUntil(timeout: 20) { self.products.count > 0 })
        let labels = (0..<products.count).map { products.element(boundBy: $0).label }
        XCTAssertTrue(labels.contains { $0.contains("Not pushed, was ") }, "\(labels)")
        XCTAssertFalse(app.radioGroups["pricing.pay.mode"].exists, "No Now | Suggested switch")
        attach("pr-prev")
    }

    /// Choosing a country through Find a country or currency, then ‹ ›.
    func testChoosingACountryThroughFindAndTheArrows() {
        app.launch(debugScene: "pricing-products")
        let picker = element("pricing.preview.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 20) { picker.label.hasPrefix("Country: United States.") }, picker.label)

        picker.click()
        let find = element("pricing.preview.menu.find")
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { (find.value(forKey: "hasKeyboardFocus") as? Bool) == true }, "Find is focused when the menu opens")
        XCTAssertTrue(element("pricing.preview.menu.group.withChanges").exists)
        XCTAssertTrue(element("pricing.preview.menu.group.all").exists)
        attach("pr-prev-menu")

        // The currency finds the country.
        app.typeText("BRL")
        let brazil = element("pricing.preview.menu.BRA")
        XCTAssertTrue(brazil.waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.preview.menu.USA").waitForNonExistence(timeout: 5))
        brazil.click()
        XCTAssertTrue(find.waitForNonExistence(timeout: 5), "The menu closes")
        XCTAssertTrue(waitUntil { picker.label.hasPrefix("Country: Brazil.") }, picker.label)

        // › goes to another country with a change; ‹ comes back.
        let next = app.buttons["pricing.preview.next"]
        XCTAssertTrue(next.isEnabled)
        next.click()
        XCTAssertTrue(waitUntil { !picker.label.hasPrefix("Country: Brazil.") }, picker.label)
        app.buttons["pricing.preview.previous"].click()
        XCTAssertTrue(waitUntil { picker.label.hasPrefix("Country: Brazil.") }, picker.label)
    }

    /// Brazil's price opened from Analytics or Reviews: the product cards,
    /// with "Preview in" on Brazil.
    func testBrazilFromAnalyticsOpensPreviewIn() {
        app.launch(debugScene: "price-br")
        let picker = element("pricing.preview.picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 20) { picker.label.hasPrefix("Country: Brazil.") }, picker.label)
        attach("price-br")
    }

    /// Nothing matches: the menu says so.
    func testFindingNothingSaysSo() {
        app.launch(debugScene: "pr-prev-menu")
        let find = element("pricing.preview.menu.find")
        XCTAssertTrue(find.waitForExistence(timeout: 20))
        app.typeText("zzz")
        let none = element("pricing.preview.menu.none")
        XCTAssertTrue(none.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: none).hasPrefix("No country or region matches"))
    }

    // MARK: - Helpers

    private var products: XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "pricing.preview.product."))
    }

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
