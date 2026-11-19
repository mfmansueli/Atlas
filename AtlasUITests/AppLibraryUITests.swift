//
//  AppLibraryUITests.swift
//  AtlasUITests
//

import XCTest

/// The main window's app library, sidebar and overview, driven through the
/// DEBUG scenes `apps`, `apps-badges`, `overview-keep`, `apps-empty`, `apps-error`,
/// `lib-loading` and `apps-unnamed` (the sample Northpier Studio account
/// from `DebugFixtures`). The apps are in the menu at the top of the
/// sidebar; the sidebar itself lists the sections (`NavigationUITests`).
@MainActor
final class AppLibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum AppID {
        static let lumen = "6450000001"
        static let habitat = "6450000002"
        static let tempo = "6450000003"
        static let fieldnote = "6450000004"
        static let parcel = "6450000005"
        static let quiet = "6450000006"
    }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheAppMenuListsTheAccountsAppsAndTheOverviewShowsTheSelectedOne() {
        launch(scene: "apps")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
        XCTAssertTrue(element("overview.subscriptionsCard").waitForExistence(timeout: 5))
        XCTAssertTrue(element("overview.storePageCard").exists)
        XCTAssertTrue(element("overview.pendingChangesCard").exists)
        openAppMenu()
        for id in [AppID.lumen, AppID.habitat, AppID.tempo, AppID.fieldnote, AppID.parcel, AppID.quiet] {
            XCTAssertTrue(element("sidebar.app.\(id)").waitForExistence(timeout: 5), "missing app \(id)")
        }
        XCTAssertTrue(element("sidebar.accountSwitcher").exists)
        XCTAssertTrue(element("sidebar.sortMenu").exists)
    }

    func testTheAppSwitcherShowsTheTeam() {
        launch(scene: "apps")
        let switcher = element("sidebar.appSwitcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10))
        XCTAssertEqual(switcher.value as? String, "Northpier Studio · Admin")
    }

    /// A key the person hasn't named shows the team's name App Store
    /// Connect gives, not "App Store Connect team".
    func testAnUnnamedKeyShowsTheTeamsNameFromAppStoreConnect() {
        launch(scene: "apps-unnamed")
        let switcher = element("sidebar.appSwitcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10))
        let named = NSPredicate(format: "value CONTAINS %@", "Northpier Studio")
        let shown = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: named, object: switcher)], timeout: 10) == .completed
        XCTAssertTrue(shown, "\(String(describing: switcher.value))")
        XCTAssertFalse((switcher.value as? String ?? "").contains("App Store Connect team"))
    }

    func testSectionsWithSuggestionsSayTheirCountAndStayClickable() {
        launch(scene: "apps-badges")
        let storePage = element("sidebar.section.storePage")
        XCTAssertTrue(storePage.waitForExistence(timeout: 10))
        XCTAssertEqual(storePage.label, "Store Page, 5 suggestions to review")
        XCTAssertEqual(element("sidebar.section.appInformation").label, "App Information, 3 suggestions to review")
        // Lumen's prices likely hold people back: Pricing counts it before it has read every product.
        XCTAssertEqual(element("sidebar.section.subscriptionPricing").label, "Pricing, 1 suggestion to review")
        XCTAssertEqual(element("sidebar.section.screenshots").label, "Screenshots")
        storePage.click()
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 5))
    }

    func testCommandDigitsSwitchSections() {
        launch(scene: "apps")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 5))
        app.typeKey("6", modifierFlags: .command)
        XCTAssertTrue(element("workspace.appInformation").waitForExistence(timeout: 5))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 5))
    }

    func testSelectingAnotherAppShowsItsOverview() {
        launch(scene: "apps")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
        openAppMenu()
        let parcel = element("sidebar.app.\(AppID.parcel)")
        XCTAssertTrue(parcel.waitForExistence(timeout: 5))
        parcel.click()
        XCTAssertTrue(app.windows.firstMatch.staticTexts["Parcel Pal"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("sidebar.appMenu").waitForNonExistence(timeout: 5), "Choosing an app closes the menu")
    }

    func testKeepMyPricesOverviewOffersSuggestionsQuietly() {
        launch(scene: "overview-keep")
        XCTAssertTrue(element("overview.showPriceSuggestions").waitForExistence(timeout: 10))
        XCTAssertFalse(element("overview.reviewSuggestions").exists)
    }

    func testReviewAndPushOpensTheReviewSheet() {
        launch(scene: "apps")
        let button = element("workspace.reviewPushButton")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.click()
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 5))
    }

    func testEmptyAccountSaysSo() {
        launch(scene: "apps-empty")
        XCTAssertTrue(app.staticTexts["No apps"].waitForExistence(timeout: 10))
    }

    func testLoadFailureOffersARetry() {
        launch(scene: "apps-error")
        XCTAssertTrue(element("sidebar.errorMessage").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sidebar.retryButton"].exists)
    }

    func testFirstSyncShowsSkeletons() {
        launch(scene: "lib-loading")
        XCTAssertTrue(element("overview.skeleton").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Syncing with App Store Connect…"].exists)
    }

    // MARK: - Helpers

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    private func openAppMenu() {
        let switcher = element("sidebar.appSwitcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10))
        switcher.click()
        XCTAssertTrue(element("sidebar.appMenu").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
