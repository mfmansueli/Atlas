//
//  NarrowWindowLayoutUITests.swift
//  AtlasUITests
//

import XCTest

/// A narrow main window keeps everything inside it. Overview's lists and
/// App Store page side by side used to hold the window's content about
/// 760 pt wider than the sidebar, so narrower windows centred it and cut
/// the sidebar on its left (“her apps”, “e Listing”), and an instant resize
/// looped the layout until the app crashed. The toolbar never needs its
/// overflow menu (Refresh and Activity left it, board 90), and Review &
/// Push stays at the bottom right, inside the window (board 80).
@MainActor
final class NarrowWindowLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheSidebarAndTheActionsStayInsideANarrowWindow() {
        app.launch(debugScene: "nav-ov")
        let reviewPush = element("workspace.reviewPushButton")
        XCTAssertTrue(reviewPush.waitForExistence(timeout: 15))
        restoresTheOpenedWidth()
        // The user's 943 pt window, a width where the labels just fit with
        // the title truncated, and the 860 pt minimum (asked for less).
        for width: CGFloat in [943, 990, 600] {
            resizeWindow(toWidth: width)
            wait(seconds: 1.5)
            let name = "\(Int(app.windows.firstMatch.frame.width)) pt"
            assertTheContentFitsTheWindow(name)
            assertTheActionsAreAtTheTrailingEdge(name)
            attach("window \(name)")
        }
    }

    /// The pages that held the window wider at its 860 pt minimum: Reviews'
    /// filter row, Screenshots' bar, App Compliance's one-line page bar and
    /// an event's Purpose menu.
    func testEverySectionFitsTheMinimumWindow() {
        // Each scene's window is put back even when a check fails.
        continueAfterFailure = true
        for scene in ["rv", "sets", "info-comp", "ev"] {
            app.launch(debugScene: scene)
            XCTAssertTrue(element("sidebar.appSwitcher").waitForExistence(timeout: 15), scene)
            let openedWidth = app.windows.firstMatch.frame.width
            resizeWindow(toWidth: 600)
            wait(seconds: 1.5)
            assertTheContentFitsTheWindow(scene)
            attach("\(scene) at the minimum")
            resizeWindow(toWidth: openedWidth)
            wait(seconds: 1)
            app.terminate()
        }
    }

    /// One language's Screenshots page with On the App Store beside it.
    /// The page measured its own width: once held wider by the preview
    /// (and the header and search tiles side by side), it kept measuring
    /// wide enough for both and cut the sidebar on the left at the user's
    /// 1,166 pt window. It now decides from the width the window offers.
    func testTheScreenshotsPageAndItsPreviewFitTheWindow() {
        continueAfterFailure = true
        app.launch(debugScene: "shots-page")
        XCTAssertTrue(element("screenshots.artwork").waitForExistence(timeout: 15))
        restoresTheOpenedWidth()
        for width: CGFloat in [1400, 1166, 1060, 943, 600, 1166] {
            resizeWindow(toWidth: width)
            wait(seconds: 1.5)
            let name = "Screenshots at \(Int(app.windows.firstMatch.frame.width)) pt"
            assertTheContentFitsTheWindow(name)
            attach(name)
        }
    }

    // MARK: - Checks

    /// The split view as wide as the window, and the sidebar's rows from
    /// its left edge.
    private func assertTheContentFitsTheWindow(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let split = app.windows.firstMatch.splitGroups.firstMatch.frame
        XCTAssertGreaterThanOrEqual(split.minX, window.minX - 1, "Split view at \(split) wider than the window \(window) at \(name)", file: file, line: line)
        XCTAssertLessThanOrEqual(split.maxX, window.maxX + 1, "Split view at \(split) wider than the window \(window) at \(name)", file: file, line: line)
        for identifier in ["sidebar.appSwitcher", "sidebar.section.overview", "sidebar.section.storePage"] {
            let frame = element(identifier).frame
            XCTAssertGreaterThanOrEqual(frame.minX, window.minX, "\(identifier) at \(frame) cut on the left at \(name)", file: file, line: line)
        }
    }

    /// No toolbar overflow menu; Refresh in the sidebar's top row; Review &
    /// Push at the bottom right, inside the window.
    private func assertTheActionsAreAtTheTrailingEdge(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let refresh = element("sidebar.refresh")
        XCTAssertTrue(refresh.exists && refresh.isHittable, "Refresh doesn't show in the sidebar at \(name)", file: file, line: line)
        let reviewPush = element("workspace.reviewPushButton")
        XCTAssertTrue(reviewPush.exists && reviewPush.isHittable, "Review & Push doesn't show at \(name)", file: file, line: line)
        XCTAssertLessThanOrEqual(reviewPush.frame.maxX, window.maxX, "Review & Push at \(reviewPush.frame) cut on the right at \(name)", file: file, line: line)
        XCTAssertLessThanOrEqual(reviewPush.frame.maxY, window.maxY, "Review & Push at \(reviewPush.frame) cut at the bottom at \(name)", file: file, line: line)
        XCTAssertGreaterThan(reviewPush.frame.minY, window.midY, "Review & Push at \(reviewPush.frame) isn't at the bottom at \(name)", file: file, line: line)
        let overflow = app.windows.firstMatch.toolbars.popUpButtons.matching(NSPredicate(format: "label CONTAINS[c] %@", "more")).firstMatch
        XCTAssertFalse(overflow.exists, "The toolbar's overflow menu shows at \(name)", file: file, line: line)
    }

    // MARK: - Helpers

    /// The window keeps its size for the next launch: the width it opened
    /// with is put back after the test.
    private func restoresTheOpenedWidth() {
        let openedWidth = app.windows.firstMatch.frame.width
        addTeardownBlock { @MainActor [self] in
            resizeWindow(toWidth: openedWidth)
        }
    }

    /// Drags the window's right edge, or its left one when the right one is
    /// at the screen's edge; it stops at the window's minimum.
    private func resizeWindow(toWidth width: CGFloat) {
        let window = app.windows.firstMatch
        let delta = width - window.frame.width
        guard abs(delta) > 1 else { return }
        let screenWidth = app.menuBars.firstMatch.frame.width
        let dragsRight = screenWidth == 0 || window.frame.maxX < screenWidth - 2
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: dragsRight ? 1 : 0, dy: 0.5))
        edge.click(forDuration: 0.2, thenDragTo: edge.withOffset(CGVector(dx: dragsRight ? delta : -delta, dy: 0)))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func wait(seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "Settling")], timeout: seconds)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
