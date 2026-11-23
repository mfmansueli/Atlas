//
//  QueuedSubscriptionOffersUITests.swift
//  AtlasUITests
//

import XCTest

/// Offers for a subscription still waiting in Review & Push, from the
/// queued subscription's menu, in the DEBUG scene `pricing-nosubs` (Quiet
/// Timer sells nothing; nothing leaves the Mac). Each offer waits under
/// the subscription and goes away with it.
@MainActor
final class QueuedSubscriptionOffersUITests: XCTestCase {
    private var app: XCUIApplication!

    private let subscriptionID = "subscriptionSetup.6450000006.dev.northpier.quiet.premium.monthly"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAPromotionalOfferWaitsUnderTheQueuedSubscriptionAndGoesWithIt() {
        app.launch(debugScene: "pricing-nosubs")
        createSubscription()
        let before = reviewCount()

        choose("newPromotional", title: "Add Promotional Offer…")
        XCTAssertTrue(element("pricing.promotionalOffer").waitForExistence(timeout: 5))
        let name = app.textFields["pricing.promotionalOffer.name"]
        name.click()
        name.typeText("Come back later")
        app.buttons["pricing.promotionalOffer.add"].click()
        XCTAssertTrue(element("pricing.promotionalOffer").waitForNonExistence(timeout: 5))

        let offer = element("pricing.newSubscriptions.\(subscriptionID).offer.promotionalOffer.6450000006.dev.northpier.quiet.premium.monthly.come_back_later")
        XCTAssertTrue(offer.waitForExistence(timeout: 5))
        XCTAssertEqual(reviewCount(), before + 1)

        // Discarding the subscription discards its offer too.
        app.buttons["pricing.newSubscriptions.\(subscriptionID).discard"].click()
        XCTAssertTrue(element("pricing.newSubscriptions.\(subscriptionID)").waitForNonExistence(timeout: 5))
        XCTAssertFalse(offer.exists)
        XCTAssertEqual(reviewCount(), before - 1)
    }

    func testEveryOfferSheetOpensForTheQueuedSubscription() {
        app.launch(debugScene: "pricing-nosubs")
        createSubscription()
        let sheets = [
            ("newPromotional", "Add Promotional Offer…", "pricing.promotionalOffer"),
            ("newWinBack", "Add Win-Back Offer…", "pricing.winBackOffer"),
            ("newOfferCode", "Add Offer Code…", "pricing.offerCode"),
        ]
        for (item, title, sheet) in sheets {
            choose(item, title: title)
            XCTAssertTrue(element(sheet).waitForExistence(timeout: 5), sheet)
            app.buttons["\(sheet).cancel"].click()
            XCTAssertTrue(element(sheet).waitForNonExistence(timeout: 5), sheet)
        }
    }

    /// Create Subscription with its description and price, queued.
    private func createSubscription() {
        let create = app.buttons["pricing.createSubscription"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.click()
        XCTAssertTrue(element("pricing.newSubscription").waitForExistence(timeout: 5))
        let description = app.textFields["pricing.newSubscription.description"]
        description.click()
        description.typeText("Every sound and timer")
        let price = app.textFields["pricing.newSubscription.price"]
        price.click()
        price.typeText("2.99")
        app.buttons["pricing.newSubscription.add"].click()
        XCTAssertTrue(element("pricing.newSubscription").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("pricing.newSubscriptions.\(subscriptionID)").waitForExistence(timeout: 5))
    }

    /// An item of the queued subscription's menu, by its identifier or else
    /// its title (macOS menu items don't always carry their identifier).
    private func choose(_ item: String, title: String) {
        let menu = element("pricing.newSubscriptions.\(subscriptionID).setup")
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.click()
        let byID = app.menuItems["pricing.newSubscriptions.\(subscriptionID).\(item)"]
        let target = byID.waitForExistence(timeout: 2) ? byID : app.menuItems[title]
        XCTAssertTrue(target.waitForExistence(timeout: 5), title)
        target.click()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The number on Review & Push, from "N changes ready" (0 when Up to date).
    private func reviewCount() -> Int {
        let value = app.buttons["workspace.reviewPushButton"].value as? String ?? ""
        return Int(value.prefix { $0.isNumber }) ?? 0
    }
}
