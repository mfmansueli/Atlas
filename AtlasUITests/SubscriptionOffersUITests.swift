//
//  SubscriptionOffersUITests.swift
//  AtlasUITests
//

import XCTest

/// Promotional offers, win-back offers and offer codes on Lumen Monthly's
/// Offers tab, in the DEBUG scenes `offers-all` (its sample offers from App
/// Store Connect) and `promo-offer`, `promo-prices`, `winback-offer`,
/// `winback-edit`, `offer-code`, `offer-code-custom`, `offer-code-batch`
/// (each sheet open). Nothing leaves the Mac.
@MainActor
final class SubscriptionOffersUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testANewPromotionalOfferIsCheckedThenQueued() {
        app.launch(debugScene: "promo-offer")
        XCTAssertTrue(element("pricing.promotionalOffer").waitForExistence(timeout: 10))
        let before = reviewCount()

        // Add without a name: the problems show and nothing is queued.
        let add = app.buttons["pricing.promotionalOffer.add"]
        add.click()
        XCTAssertTrue(element("pricing.promotionalOffer.problems").waitForExistence(timeout: 5))

        let name = app.textFields["pricing.promotionalOffer.name"]
        name.click()
        name.typeText("Come back later")
        // The identifier follows the name until it's typed.
        XCTAssertEqual(text(of: app.textFields["pricing.promotionalOffer.identifier"]), "come_back_later")
        add.click()

        XCTAssertTrue(element("pricing.promotionalOffer").waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
        XCTAssertTrue(element("pricing.offers.queued.promotionalOffer.6450000001.lumen.plus.monthly.come_back_later").waitForExistence(timeout: 5))
    }

    func testTheOffersTabShowsWhatAppStoreConnectHasWithItsActions() {
        app.launch(debugScene: "offers-all")
        XCTAssertTrue(element("pricing.offers.list").waitForExistence(timeout: 10))
        XCTAssertTrue(element("pricing.offer.promotional.6600000001").exists)
        XCTAssertTrue(element("pricing.offer.winBack.6600000002").exists)
        XCTAssertTrue(element("pricing.offer.offerCode.6600000003").exists)
        XCTAssertTrue(element("pricing.offers.newMenu").exists)

        // The offer code is selected: its codes and actions show.
        XCTAssertTrue(element("pricing.offerActions").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pricing.offerCodes.custom.6600000004").exists)
        XCTAssertTrue(app.buttons["pricing.offerCodes.batch.6600000005.save"].exists)
        app.buttons["pricing.offerActions.addCustomCode"].click()
        XCTAssertTrue(element("pricing.customCode").waitForExistence(timeout: 5))
        app.buttons["pricing.customCode.cancel"].click()
        XCTAssertTrue(element("pricing.customCode").waitForNonExistence(timeout: 5))

        // Deactivating asks first, then queues it.
        let before = reviewCount()
        app.buttons["pricing.offerActions.deactivate"].click()
        let confirm = app.buttons["pricing.offerActions.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()
        XCTAssertTrue(element("pricing.offerActions.waiting").waitForExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)

        // A promotional offer offers its prices and deletion.
        element("pricing.offer.promotional.6600000001").click()
        XCTAssertTrue(app.buttons["pricing.offerActions.prices"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pricing.offerActions.delete"].exists)
    }

    func testEverySheetOpensOnLumenMonthly() {
        let sheets = [
            ("promo-prices", "pricing.promotionalPrices"),
            ("winback-offer", "pricing.winBackOffer"),
            ("winback-edit", "pricing.winBackSettings"),
            ("offer-code", "pricing.offerCode"),
            ("offer-code-custom", "pricing.customCode"),
            ("offer-code-batch", "pricing.oneTimeCodes"),
        ]
        for (scene, identifier) in sheets {
            app.launch(debugScene: scene)
            XCTAssertTrue(element(identifier).waitForExistence(timeout: 10), scene)
            app.buttons["\(identifier).cancel"].click()
            XCTAssertTrue(element(identifier).waitForNonExistence(timeout: 5), scene)
            app.terminate()
        }
    }

    func testANewWinBackOfferIsQueued() {
        app.launch(debugScene: "winback-offer")
        XCTAssertTrue(element("pricing.winBackOffer").waitForExistence(timeout: 10))
        let before = reviewCount()
        let name = app.textFields["pricing.winBackOffer.name"]
        name.click()
        name.typeText("We miss you")
        XCTAssertEqual(text(of: app.textFields["pricing.winBackOffer.offerID"]), "we_miss_you")
        app.buttons["pricing.winBackOffer.add"].click()
        XCTAssertTrue(element("pricing.winBackOffer").waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
    }

    func testANewOfferCodeWithACustomCodeIsQueued() {
        app.launch(debugScene: "offer-code")
        XCTAssertTrue(element("pricing.offerCode").waitForExistence(timeout: 10))
        let before = reviewCount()
        let name = app.textFields["pricing.offerCode.name"]
        name.click()
        name.typeText("Newsletter")
        // The switch sits below the sheet's fold, and XCUITest on macOS
        // doesn't scroll a Form to it.
        let hasCustomCode = revealed("pricing.offerCode.hasCustomCode", in: element("pricing.offerCode"))
        hasCustomCode.click()
        let code = revealed("pricing.offerCode.customCode", in: element("pricing.offerCode"))
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.click()
        code.typeText("news30")
        app.buttons["pricing.offerCode.add"].click()
        XCTAssertTrue(element("pricing.offerCode").waitForNonExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)
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
