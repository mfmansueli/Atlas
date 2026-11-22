//
//  NewInAppPurchaseUITests.swift
//  AtlasUITests
//

import XCTest

/// Create In-App Purchase from Pricing's empty state, in the DEBUG scene
/// `pricing-nosubs` (Quiet Timer sells nothing; nothing leaves the Mac),
/// and the setup sheets over Lumen's cards (`new-iap`, `intro-offer`,
/// `review-screenshot`).
@MainActor
final class NewInAppPurchaseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testCreatingAnInAppPurchaseQueuesItForReview() {
        app.launch(debugScene: "pricing-nosubs")
        let create = app.buttons["pricing.createInAppPurchase"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        let before = reviewCount()
        create.click()

        XCTAssertTrue(element("pricing.newInAppPurchase").waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: app.textFields["pricing.newInAppPurchase.productID"]), "dev.northpier.quiet.lifetime")
        XCTAssertTrue(element("pricing.reviewScreenshot").exists)

        // Add without a description or price: both are named, nothing is queued.
        let add = app.buttons["pricing.newInAppPurchase.add"]
        add.click()
        XCTAssertTrue(element("pricing.newInAppPurchase.purchaseDescription.problem").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.newInAppPurchase.price.problem").exists)
        let description = app.textFields["pricing.newInAppPurchase.purchaseDescription"]
        description.click()
        description.typeText("Every sound and timer, once")
        let price = app.textFields["pricing.newInAppPurchase.price"]
        price.click()
        price.typeText("29.99")
        add.click()

        XCTAssertTrue(element("pricing.newInAppPurchase").waitForNonExistence(timeout: 5))
        let row = element("pricing.newSubscriptions.inAppPurchaseSetup.6450000006.dev.northpier.quiet.lifetime")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
        XCTAssertTrue(element("pricing.newSubscriptions.inAppPurchaseSetup.6450000006.dev.northpier.quiet.lifetime.setup").exists)
    }

    func testTheSetupSheetsOpenOverTheCards() {
        app.launch(debugScene: "intro-offer")
        XCTAssertTrue(element("pricing.introductoryOffer").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pricing.introductoryOffer.mode").exists)
        app.buttons["pricing.introductoryOffer.cancel"].click()
        XCTAssertTrue(element("pricing.introductoryOffer").waitForNonExistence(timeout: 5))
        app.terminate()

        app.launch(debugScene: "review-screenshot")
        XCTAssertTrue(element("pricing.reviewScreenshotSheet").waitForExistence(timeout: 10))
        // Nothing chosen yet: nothing to add.
        XCTAssertFalse(app.buttons["pricing.reviewScreenshotSheet.add"].isEnabled)
        app.buttons["pricing.reviewScreenshotSheet.cancel"].click()
        XCTAssertTrue(element("pricing.reviewScreenshotSheet").waitForNonExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
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
