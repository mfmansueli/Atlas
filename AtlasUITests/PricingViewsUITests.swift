//
//  PricingViewsUITests.swift
//  AtlasUITests
//

import XCTest

/// A product's page beyond the table (board 73): the map and histogram,
/// when price changes start, Results and Offers, driven through the DEBUG
/// scenes in `PricingDebugScenes` (sample data; nothing leaves the Mac).
@MainActor
final class PricingViewsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// A new product waiting in Review & Push without its review screenshot
    /// says so, with Review Screenshot… beside it.
    func testAQueuedProductWithoutAReviewScreenshotSaysSo() {
        launch(scene: "pr-newsub-noshot")
        let missing = elements(prefixed: "pricing.newSubscriptions.")
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".reviewScreenshotMissing"))
            .firstMatch
        XCTAssertTrue(missing.waitForExistence(timeout: 20))
        let button = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", ".reviewScreenshot")).firstMatch
        XCTAssertTrue(button.exists)
        button.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
    }

    /// Accept on a product's price suggestion is a row action (tinted, so
    /// Accept All stays the one filled button). Accepted, the suggestion
    /// settles and closes, and its prices wait in Review & Push.
    func testAcceptingAPriceSuggestionSettlesItAway() {
        launch(scene: "pricing-products")
        let accept = app.buttons.matching(identifier: "pricing.card.accept").firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 20))
        let suggestions = app.buttons.matching(identifier: "pricing.card.accept").count
        let before = reviewCount()
        accept.click()
        let closed = NSPredicate { _, _ in
            self.app.buttons.matching(identifier: "pricing.card.accept").count == suggestions - 1
        }
        wait(for: [XCTNSPredicateExpectation(predicate: closed, object: app)], timeout: 10)
        let queued = NSPredicate { _, _ in self.reviewCount() > before }
        wait(for: [XCTNSPredicateExpectation(predicate: queued, object: app)], timeout: 10)
    }

    func testSwitchingToTheMapAndTheHistogram() {
        launch(scene: "pricing-applied")
        let picker = element("countries.display")
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        segment(1, of: picker).click()
        XCTAssertTrue(element("countries.map").waitForExistence(timeout: 5))
        XCTAssertFalse(element("countries.table").exists)
        element("countries.map.tile.BRA").click()
        XCTAssertTrue(element("countries.popover").waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])

        segment(2, of: picker).click()
        XCTAssertTrue(element("countries.histogram").waitForExistence(timeout: 5))

        segment(0, of: picker).click()
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 5))
    }

    func testTheScheduleWarnsAboutIncreases() {
        launch(scene: "schedule")
        XCTAssertTrue(element("pricing.scheduleSheet").waitForExistence(timeout: 10))
        let consent = element("pricing.schedule.consent")
        XCTAssertTrue(consent.exists)
        let title = consent.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "go up", "go up")).firstMatch
        XCTAssertTrue(title.exists)
        XCTAssertTrue(text(of: title).contains("existing subscribers"))
        app.buttons["pricing.schedule.cancel"].click()
        XCTAssertTrue(element("pricing.scheduleSheet").waitForNonExistence(timeout: 5))
    }

    func testSchedulingTheChangesForADate() {
        launch(scene: "pricing-applied")
        let start = element("countries.start")
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.click()
        let onDate = app.menuItems["On a Date…"]
        XCTAssertTrue(onDate.waitForExistence(timeout: 5))
        onDate.click()
        XCTAssertTrue(element("pricing.scheduleSheet").waitForExistence(timeout: 5))
        element("pricing.schedule.start").radioButtons["On a date"].click()
        app.buttons["pricing.schedule.save"].click()
        XCTAssertTrue(element("pricing.scheduleSheet").waitForNonExistence(timeout: 5))
        XCTAssertFalse(text(of: element("countries.start")).contains("Right Away"))
    }

    func testRestoringATerritoryFromResults() {
        launch(scene: "results")
        XCTAssertTrue(element("pricing.results.table").waitForExistence(timeout: 10))
        let restore = app.buttons["pricing.results.restore.JPN"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        let before = reviewCount()
        restore.click()
        XCTAssertTrue(element("pricing.results.restored.JPN").waitForExistence(timeout: 5))
        XCTAssertFalse(restore.exists)
        XCTAssertEqual(reviewCount(), before + 1)
        app.buttons["workspace.reviewPushButton"].click()
        XCTAssertTrue(element("review.row.price.6450100002.JPN").waitForExistence(timeout: 5))
    }

    func testTheOffersTable() {
        launch(scene: "offers")
        let table = element("pricing.offers.table")
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        XCTAssertEqual(elements(prefixed: "pricing.offers.row.").count, 9)
        XCTAssertTrue(element("pricing.offers.row.USA").exists)
        element("pricing.offer.intro").click()
        let title = element("pricing.offerDetail").staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", "1 week free", "1 week free"))
        XCTAssertTrue(title.firstMatch.waitForExistence(timeout: 5))
    }

    func testTheTabsOpenResultsAndOffers() {
        launch(scene: "pricing-applied")
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 20))
        tab("Results").click()
        XCTAssertTrue(element("pricing.results").waitForExistence(timeout: 5))
        tab("Offers").click()
        XCTAssertTrue(element("pricing.offers").waitForExistence(timeout: 5))
        tab("Prices by Country").click()
        XCTAssertTrue(element("countries.table").waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func elements(prefixed prefix: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    /// A tab of the product page's segments, by its name.
    private func tab(_ title: String) -> XCUIElement {
        let segment = element("pricing.product.tabs").buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No \(title) tab")
        return segment
    }

    /// One segment of a segmented control, which macOS exposes as a radio
    /// group.
    private func segment(_ index: Int, of control: XCUIElement) -> XCUIElement {
        control.radioButtons.element(boundBy: index)
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
