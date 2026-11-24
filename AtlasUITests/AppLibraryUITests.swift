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
        // README — redesign, November 22: the Overview is three lists.
        XCTAssertTrue(element("overview.waiting").waitForExistence(timeout: 5))
        XCTAssertTrue(element("overview.afterRelease").exists)
        XCTAssertTrue(element("overview.storePreview").exists)
        openAppMenu()
        for id in [AppID.lumen, AppID.habitat, AppID.tempo, AppID.fieldnote, AppID.parcel, AppID.quiet] {
            XCTAssertTrue(element("sidebar.app.\(id)").waitForExistence(timeout: 5), "missing app \(id)")
        }
        XCTAssertTrue(element("sidebar.accountSwitcher").exists)
        XCTAssertTrue(element("sidebar.sortMenu").exists)
    }

    /// In Free, the app menu marks every app but the free one (the first
    /// opened, Lumen) as needing Pro, and choosing one opens the paywall.
    func testInFreeTheOtherAppsSayTheyNeedPro() {
        app.launchArguments = ["-AtlasDebugScene", "apps", "-AtlasPro", "free", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
        openAppMenu()
        let lumen = element("sidebar.app.\(AppID.lumen)")
        let habitat = element("sidebar.app.\(AppID.habitat)")
        XCTAssertTrue(habitat.waitForExistence(timeout: 5))
        XCTAssertNotEqual(lumen.value as? String, "Needs Atlas Pro")
        XCTAssertEqual(habitat.value as? String, "Needs Atlas Pro")
        habitat.click()
        XCTAssertTrue(element("paywall.sheet").waitForExistence(timeout: 5))
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

    /// The app menu and the first sections stay reachable after the last
    /// section is opened and another app is chosen: the list starts at its
    /// top again and never scrolls the app menu away.
    func testTheSidebarKeepsTheAppMenuAndTopSectionsAfterSwitchingApps() {
        launch(scene: "apps")
        let analytics = element("sidebar.section.analytics")
        XCTAssertTrue(analytics.waitForExistence(timeout: 10))
        analytics.click()
        openAppMenu()
        let habitat = element("sidebar.app.\(AppID.habitat)")
        XCTAssertTrue(habitat.waitForExistence(timeout: 5))
        habitat.click()
        let switcher = element("sidebar.appSwitcher")
        let overview = element("sidebar.section.overview")
        XCTAssertTrue(overview.waitForExistence(timeout: 10))
        XCTAssertTrue(switcher.isHittable)
        XCTAssertTrue(overview.isHittable)
        overview.click()
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 5))
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

    /// Keep My Prices: Pricing has nothing to review on the Overview, so its
    /// row is Reviewed with Open.
    func testKeepMyPricesOverviewOffersSuggestionsQuietly() {
        launch(scene: "overview-keep")
        let open = app.buttons["overview.waiting.open.subscriptionPricing"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertFalse(open.label.contains("suggestion"), open.label)
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
        XCTAssertTrue(app.staticTexts["Reading apps from App Store Connect…"].exists)
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
