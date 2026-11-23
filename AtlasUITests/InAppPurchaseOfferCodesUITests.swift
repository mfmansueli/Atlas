//
//  InAppPurchaseOfferCodesUITests.swift
//  AtlasUITests
//

import XCTest

/// Offer codes on Lumen Lifetime's (an in-app purchase's) Offers tab, in
/// the DEBUG scenes `iap-offers` (its sample offer code from App Store
/// Connect, selected) and `iap-offer-code`, `iap-offer-code-custom`,
/// `iap-offer-code-batch` (each sheet open). Nothing leaves the Mac.
@MainActor
final class InAppPurchaseOfferCodesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testANewOfferCodeIsCheckedThenQueued() {
        app.launch(debugScene: "iap-offer-code")
        let sheet = element("pricing.iapOfferCode")
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let before = reviewCount()

        // Add without a name: the problems show and nothing is queued.
        let add = app.buttons["pricing.iapOfferCode.add"]
        add.click()
        XCTAssertTrue(element("pricing.iapOfferCode.problems").waitForExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before)

        let name = app.textFields["pricing.iapOfferCode.name"]
        name.click()
        name.typeText("Press")
        add.click()

        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
        XCTAssertTrue(element("pricing.offers.queued.iapOfferCode.6450000001.lumen.lifetime.press").waitForExistence(timeout: 5))
    }

    func testALowerPriceWithACustomCodeIsQueued() {
        app.launch(debugScene: "iap-offer-code")
        let sheet = element("pricing.iapOfferCode")
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let before = reviewCount()
        let name = app.textFields["pricing.iapOfferCode.name"]
        name.click()
        name.typeText("Podcast listeners")
        // Who can redeem it: people who stopped buying too.
        revealed("pricing.iapOfferCode.eligibility.CHURNED_SPENDER", in: sheet).click()

        // A lower price than Lifetime's $79.99.
        revealed("pricing.iapOfferCode.free", in: sheet).radioButtons["A lower price"].click()
        let price = revealed("pricing.iapOfferCode.price", in: sheet)
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.click()
        price.typeText("29.99")

        // The custom code sits below the sheet's fold, and XCUITest on
        // macOS doesn't scroll a Form to it.
        revealed("pricing.iapOfferCode.hasCustomCode", in: sheet).click()
        let code = revealed("pricing.iapOfferCode.customCode", in: sheet)
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.click()
        code.typeText("podcast30")
        app.buttons["pricing.iapOfferCode.add"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
    }

    func testTheOffersTabShowsTheOfferCodeWithItsActions() {
        app.launch(debugScene: "iap-offers")
        XCTAssertTrue(element("pricing.iapOffers.list").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pricing.offer.iapOfferCode.6600000011").exists)
        XCTAssertTrue(app.buttons["pricing.iapOffers.new"].exists)

        // The offer code is selected: its details, codes and actions show.
        XCTAssertTrue(element("pricing.iapOfferActions").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.iapOfferDetail").exists)
        XCTAssertTrue(element("pricing.offerCodes.custom.6600000012").exists)
        XCTAssertTrue(app.buttons["pricing.offerCodes.batch.6600000013.save"].exists)

        app.buttons["pricing.iapOfferActions.addCustomCode"].click()
        XCTAssertTrue(element("pricing.customCode").waitForExistence(timeout: 5))
        app.buttons["pricing.customCode.cancel"].click()
        XCTAssertTrue(element("pricing.customCode").waitForNonExistence(timeout: 5))

        app.buttons["pricing.iapOfferActions.addOneTimeCodes"].click()
        XCTAssertTrue(element("pricing.oneTimeCodes").waitForExistence(timeout: 5))
        app.buttons["pricing.oneTimeCodes.cancel"].click()
        XCTAssertTrue(element("pricing.oneTimeCodes").waitForNonExistence(timeout: 5))

        // Deactivating asks first, then queues it.
        let before = reviewCount()
        app.buttons["pricing.iapOfferActions.deactivate"].click()
        let confirm = app.buttons["pricing.iapOfferActions.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()
        XCTAssertTrue(element("pricing.iapOfferActions.waiting").waitForExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
    }

    func testTheCodesSheetsQueueForTheOfferCodeItHas() {
        app.launch(debugScene: "iap-offer-code-custom")
        XCTAssertTrue(element("pricing.customCode").waitForExistence(timeout: 10))
        let before = reviewCount()
        let code = app.textFields["pricing.customCode.customCode"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.click()
        code.typeText("spring")
        app.buttons["pricing.customCode.add"].click()
        XCTAssertTrue(element("pricing.customCode").waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
        app.terminate()

        app.launch(debugScene: "iap-offer-code-batch")
        XCTAssertTrue(element("pricing.oneTimeCodes").waitForExistence(timeout: 10))
        app.buttons["pricing.oneTimeCodes.cancel"].click()
        XCTAssertTrue(element("pricing.oneTimeCodes").waitForNonExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The element, after scrolling `container` down until it's on screen.
    private func revealed(_ identifier: String, in container: XCUIElement) -> XCUIElement {
        let target = element(identifier)
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            container.scroll(byDeltaX: 0, deltaY: -200)
        }
        return target
    }

    /// The number on Review & Push, from "N changes ready" (0 when Up to date).
    private func reviewCount() -> Int {
        let value = app.buttons["workspace.reviewPushButton"].value as? String ?? ""
        return Int(value.prefix { $0.isNumber }) ?? 0
    }
}
