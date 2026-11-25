//
//  PricingProductPageUITests.swift
//  AtlasUITests
//

import XCTest

/// A product's page inside Pricing (board 73): the top of its card opens
/// it, its tabs switch, and the breadcrumb, ⌘[ and Pricing in the sidebar
/// go back to the cards. Driven through the DEBUG scenes in
/// `PricingDebugScenes` and `PricingProductPageDebugScenes` (sample data;
/// nothing leaves the Mac).
@MainActor
final class PricingProductPageUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testOpeningAProductSwitchingTabsAndGoingBack() {
        app.launch(debugScene: "pricing-products")
        openAnnual()

        XCTAssertTrue(element("pricing.product.breadcrumb").exists)
        tab("Offers").click()
        XCTAssertTrue(element("pricing.offers").waitForExistence(timeout: 10))
        tab("Review Screenshot").click()
        XCTAssertTrue(element("pricing.product.reviewScreenshot").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pricing.product.reviewScreenshot.choose"].exists)
        tab("Details").click()
        XCTAssertTrue(element("pricing.product.details").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.product.details.productID").waitForExistence(timeout: 5))

        // The breadcrumb's Pricing.
        element("pricing.product.back").click()
        XCTAssertTrue(element("pricing.products").waitForExistence(timeout: 5))
        XCTAssertFalse(element("pricing.product").exists)

        // ⌘[.
        openAnnual()
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(element("pricing.products").waitForExistence(timeout: 5))
        XCTAssertFalse(element("pricing.product").exists)
    }

    func testShowCountriesOpensTheProductsPage() {
        app.launch(debugScene: "pricing-products")
        let show = app.buttons.matching(identifier: "pricing.card.showCountries").firstMatch
        XCTAssertTrue(show.waitForExistence(timeout: 20))
        show.click()
        XCTAssertTrue(element("pricing.product").waitForExistence(timeout: 5))
        XCTAssertTrue(tab("Prices by Country").exists)
    }

    func testPricingInTheSidebarGoesBackToTheCards() {
        app.launch(debugScene: "pr-prod-details")
        XCTAssertTrue(element("pricing.product.details").waitForExistence(timeout: 20))
        element("sidebar.section.subscriptionPricing").click()
        XCTAssertTrue(element("pricing.products").waitForExistence(timeout: 5))
        XCTAssertFalse(element("pricing.product").exists)
    }

    func testAOneTimePurchaseHasNoSubscriptionOffers() {
        app.launch(debugScene: "pr-prod-life-offers")
        XCTAssertTrue(element("pricing.product.offers.oneTime").waitForExistence(timeout: 20))
        XCTAssertTrue(element("pricing.offers").waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    /// Clicks the top of Lumen Plus Annual's card and waits for its page.
    private func openAnnual() {
        let open = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "pricing.card.openPage", "Lumen Plus Annual")
        ).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        open.click()
        XCTAssertTrue(element("pricing.product").waitForExistence(timeout: 5))
    }

    /// A tab of the product page's segments, by its name.
    private func tab(_ title: String) -> XCUIElement {
        let segment = element("pricing.product.tabs").buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No \(title) tab")
        return segment
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
