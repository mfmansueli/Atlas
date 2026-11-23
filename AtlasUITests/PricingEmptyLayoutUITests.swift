//
//  PricingEmptyLayoutUITests.swift
//  AtlasUITests
//

import XCTest

/// Pricing for an app that sells nothing: App Price and Availability above
/// the empty state. Their wrapping texts once gave the page a minimum
/// height of thousands of points, so the window's whole content was
/// centered and cut off at the top, the sidebar's app menu with it.
@MainActor
final class PricingEmptyLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheWindowsContentStaysInsideTheWindow() {
        app.launch(debugScene: "pricing-nosubs")
        let window = app.windows.firstMatch
        let switcher = app.descendants(matching: .any)["sidebar.appSwitcher"]
        let appPrice = app.descendants(matching: .any)["pricing.appPrice"]
        let availability = app.descendants(matching: .any)["pricing.availability"]
        XCTAssertTrue(appPrice.waitForExistence(timeout: 15))
        XCTAssertTrue(switcher.isHittable)
        XCTAssertGreaterThanOrEqual(switcher.frame.minY, window.frame.minY)
        XCTAssertGreaterThanOrEqual(appPrice.frame.minY, window.frame.minY)
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.section.overview"].isHittable)
        // The cards are only as tall as their content.
        XCTAssertLessThan(appPrice.frame.height, 300)
        XCTAssertLessThan(availability.frame.height, 300)
    }
}
