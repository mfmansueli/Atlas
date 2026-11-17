//
//  NavigationUITests.swift
//  AtlasUITests
//

import XCTest

/// The sidebar navigation in its DEBUG scenes (boards 41–43): the sections
/// grouped in the sidebar with their counts, ⌘1–⌘8, the app menu, the
/// version's status in the footer, and the toolbar's section menu while
/// the sidebar is hidden.
@MainActor
final class NavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum AppID {
        static let habitat = "6450000002"
    }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheSidebarListsTheSectionsInGroupsAndSwitchesThem() {
        app.launch(debugScene: "nav-ov")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Store Listing"].exists)
        XCTAssertTrue(app.staticTexts["After Release"].exists)
        XCTAssertFalse(element("workspace.sectionPicker").exists, "The sections left the toolbar")
        attach("nav-ov")
        element("sidebar.section.storePage").click()
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 10))
        element("sidebar.section.inAppEvents").click()
        XCTAssertTrue(element("workspace.inAppEvents").waitForExistence(timeout: 10))
        element("sidebar.section.reviews").click()
        XCTAssertTrue(element("workspace.reviews").waitForExistence(timeout: 10))
        element("sidebar.section.overview").click()
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
    }

    func testEachSectionSaysItsCount() {
        app.launch(debugScene: "nav-ov")
        let storePage = element("sidebar.section.storePage")
        XCTAssertTrue(storePage.waitForExistence(timeout: 15))
        XCTAssertTrue(text(of: storePage).contains("suggestions to review"), text(of: storePage))
        // Six replies are suggested for the reviews that need one, and nine
        // languages for the Winter Reflection Challenge.
        XCTAssertEqual(element("sidebar.section.reviews").label, "Reviews, 6 suggestions to review")
        XCTAssertEqual(element("sidebar.section.inAppEvents").label, "In-App Events, 9 suggestions to review")
        XCTAssertEqual(element("sidebar.section.overview").label, "Overview")
    }

    func testCommandDigitsFollowTheSidebarsOrder() {
        app.launch(debugScene: "nav-ov")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 10))
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(element("workspace.inAppEvents").waitForExistence(timeout: 10))
        app.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(element("workspace.reviews").waitForExistence(timeout: 10))
        app.typeKey("8", modifierFlags: .command)
        XCTAssertTrue(element("workspace.analytics").waitForExistence(timeout: 10))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 10))
    }

    func testTheAppMenuListsEveryAppAndSwitches() {
        app.launch(debugScene: "nav-apps")
        XCTAssertTrue(element("sidebar.appMenu").waitForExistence(timeout: 15))
        attach("nav-apps")
        let habitat = element("sidebar.app.\(AppID.habitat)")
        XCTAssertTrue(habitat.waitForExistence(timeout: 5))
        XCTAssertTrue(element("sidebar.accountSwitcher").exists)
        habitat.click()
        let switcher = element("sidebar.appSwitcher")
        let showsHabitat = NSPredicate(format: "label CONTAINS %@", "Habitat")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: showsHabitat, object: switcher)], timeout: 10), .completed, switcher.label)
    }

    func testTheFooterOpensSubmitBeforeSubmitting() {
        app.launch(debugScene: "nav-ov")
        let footer = element("sidebar.version")
        XCTAssertTrue(footer.waitForExistence(timeout: 15))
        let notSubmitted = NSPredicate(format: "label == %@", "Version 1.4, Not submitted yet")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: notSubmitted, object: footer)], timeout: 10), .completed, footer.label)
        footer.click()
        XCTAssertTrue(element("submit.sheet").waitForExistence(timeout: 10))
    }

    func testTheFooterFollowsAPhasedReleaseFromAnySection() {
        app.launch(debugScene: "nav-ph")
        XCTAssertTrue(element("workspace.reviews").waitForExistence(timeout: 15))
        let footer = element("sidebar.version")
        let rollingOut = NSPredicate(format: "label == %@", "Version 1.4, Rolling out · day 3 of 7")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rollingOut, object: footer)], timeout: 10), .completed, footer.label)
        attach("nav-ph")
        footer.click()
        XCTAssertTrue(element("overview.version").waitForExistence(timeout: 10))
    }

    func testWithTheSidebarHiddenTheToolbarHasTheSectionMenu() {
        app.launch(debugScene: "nav-s")
        let menu = element("workspace.sectionMenu")
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertEqual(menu.label, "Section: Store Page")
        XCTAssertFalse(element("sidebar.section.storePage").exists)
        let title = element("workspace.title")
        XCTAssertTrue(title.exists)
        XCTAssertTrue(text(of: title).contains("Version 1.4"), text(of: title))
        attach("nav-s")
        menu.click()
        let reviews = element("workspace.sectionMenu.item.reviews")
        XCTAssertTrue(reviews.waitForExistence(timeout: 5))
        attach("nav-s-menu")
        reviews.click()
        XCTAssertTrue(element("workspace.reviews").waitForExistence(timeout: 10))
        XCTAssertEqual(element("workspace.sectionMenu").label, "Section: Reviews")
    }

    func testHidingTheSidebarMovesTheSectionsToTheToolbarAndBack() {
        app.launch(debugScene: "nav-ov")
        XCTAssertTrue(element("sidebar.section.overview").waitForExistence(timeout: 15))
        XCTAssertFalse(element("workspace.sectionMenu").exists)
        XCTAssertTrue(sidebarToggle.exists)
        sidebarToggle.click()
        let menu = element("workspace.sectionMenu")
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertEqual(menu.label, "Section: Overview")
        XCTAssertTrue(element("sidebar.section.overview").waitForNonExistence(timeout: 5))
        sidebarToggle.click()
        XCTAssertTrue(element("sidebar.section.overview").waitForExistence(timeout: 5))
        XCTAssertTrue(element("workspace.sectionMenu").waitForNonExistence(timeout: 5))
    }

    func testFreeKeepsTheProButtonInTheToolbar() {
        app.launch(debugScene: "nav-free")
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 15))
        XCTAssertTrue(element("workspace.proButton").exists)
        XCTAssertTrue(element("sidebar.section.reviews").exists)
        attach("nav-free")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The window's own button that shows and hides the sidebar.
    private var sidebarToggle: XCUIElement {
        let named = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "sidebar", "toggleSidebar")
        return app.windows.firstMatch.toolbars.buttons.matching(named).firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
