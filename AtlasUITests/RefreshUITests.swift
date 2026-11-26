//
//  RefreshUITests.swift
//  AtlasUITests
//

import XCTest

/// Refresh (README-DS §15, board 90), through `RefreshDebugScenes`: the
/// sidebar's arrow is off while it reads and comes back; a failed Refresh
/// says so at the end of the status line, with Details… opening the
/// error sheet; ⌘R does the same as the button.
@MainActor
final class RefreshUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testRefreshTurnsOffWhileItReadsAndComesBack() {
        app.launch(debugScene: "rf-slow")
        let refresh = app.buttons["sidebar.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 10))
        refresh.click()
        XCTAssertTrue(waitUntil(refresh, isEnabled: false, timeout: 2), "off while it reads")
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 25), "back once everything is in")
        XCTAssertFalse(element("refresh.status").exists, "a good Refresh says nothing in the status line")
    }

    func testCommandRRefreshes() {
        app.launch(debugScene: "rf-slow")
        let refresh = app.buttons["sidebar.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 10))
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(waitUntil(refresh, isEnabled: false, timeout: 2))
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 25))
    }

    func testAFailedRefreshOffersDetails() {
        app.launch(debugScene: "rf-fail")
        let refresh = app.buttons["sidebar.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 10))
        refresh.click()
        XCTAssertTrue(element("refresh.status").waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["Couldn’t update"].exists)
        // A link-styled button: VoiceOver reads it as a link.
        element("refresh.details").click()

        XCTAssertTrue(element("refresh.error").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Couldn’t Update from App Store Connect"].exists)
        XCTAssertFalse(element("refresh.error.code").exists, "the code shows only under Show Details")
        element("refresh.error.details").click()
        XCTAssertTrue(element("refresh.error.code").waitForExistence(timeout: 5))
        app.buttons["refresh.error.close"].click()
        XCTAssertTrue(element("refresh.error").waitForNonExistence(timeout: 5))
    }

    func testOfflineSaysWhereWhatShowsIsFrom() {
        app.launch(debugScene: "rf-off")
        let refresh = app.buttons["sidebar.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(refresh, isEnabled: true, timeout: 10))
        refresh.click()
        XCTAssertTrue(element("refresh.status").waitForExistence(timeout: 25))
        // A Text's words are its value on macOS, not its label.
        let prefix = "Offline · from "
        let offline = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix)).firstMatch
        XCTAssertTrue(offline.exists)
    }

    /// The toolbar's own icon button, like Hide Sidebar beside it: the same
    /// glass circle, right next to it. A borderless 28 pt frame drew a
    /// narrower pill, and `DefaultToolbarItem(kind: .sidebarToggle)` an
    /// empty item between them that stretched Refresh's glass.
    func testRefreshIsTheSameSizeAsHideSidebarAndBesideIt() {
        app.launch(debugScene: "rf-slow")
        let refresh = app.buttons["sidebar.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        let toggle = sidebarToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Hide Sidebar shows")
        XCTAssertEqual(refresh.frame.width, toggle.frame.width, accuracy: 1, "Refresh at \(refresh.frame), Hide Sidebar at \(toggle.frame)")
        XCTAssertEqual(refresh.frame.height, toggle.frame.height, accuracy: 1, "Refresh at \(refresh.frame), Hide Sidebar at \(toggle.frame)")
        let gap = toggle.frame.minX - refresh.frame.maxX
        XCTAssertTrue((0...12).contains(gap), "\(gap) pt between Refresh and Hide Sidebar")
    }

    func testWithTheSidebarHiddenRefreshIsInTheToolbar() {
        app.launch(debugScene: "rf-side")
        XCTAssertTrue(app.buttons["workspace.refreshButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["sidebar.refresh"].exists)
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The window's own button that shows and hides the sidebar.
    private var sidebarToggle: XCUIElement {
        let named = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "sidebar", "toggleSidebar")
        return app.windows.firstMatch.toolbars.buttons.matching(named).firstMatch
    }

    private func waitUntil(_ element: XCUIElement, isEnabled: Bool, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: isEnabled)), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
