//
//  SidebarFooterUITests.swift
//  AtlasUITests
//

import XCTest

/// Board 71: Settings and Help ▾ sit side by side with their names at
/// every height, Help ▾ opens Atlas Help, Show the Tour and Keyboard
/// Shortcuts, and in the smallest window every section still shows above
/// the footer.
@MainActor
final class SidebarFooterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testHelpOpensItsMenu() {
        app.launch(debugScene: "nav-ov")
        let help = element("sidebar.help")
        XCTAssertTrue(help.waitForExistence(timeout: 15))
        help.click()
        for title in ["Atlas Help", "Show the Tour", "Keyboard Shortcuts"] {
            XCTAssertTrue(help.menuItems[title].waitForExistence(timeout: 5), "Help ▾ has \(title)")
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    func testTheFooterKeepsItsNamesAndNeverCoversASection() {
        app.launch(debugScene: "nav-ov")
        let settings = element("sidebar.settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        let window = app.windows.firstMatch
        let height = window.frame.height
        // The window keeps its size for the next launch, the other tests'
        // and the app's own: put it back.
        addTeardownBlock { @MainActor [self] in
            resizeWindow(toHeight: height)
        }

        resizeWindow(toHeight: 820)
        assertSideBySide()
        assertNothingCovered()

        resizeWindow(toHeight: 0)
        XCTAssertLessThan(window.frame.height, 600, "The window didn't get shorter than 600 pt.")
        assertSideBySide()
        assertNothingCovered()
    }

    // MARK: - Helpers

    /// Settings and Help on one row, each wide enough for its name.
    private func assertSideBySide(file: StaticString = #filePath, line: UInt = #line) {
        let settings = element("sidebar.settings").frame
        let help = element("sidebar.help").frame
        XCTAssertEqual(settings.midY, help.midY, accuracy: 1, "One row", file: file, line: line)
        XCTAssertGreaterThan(settings.width, 70, "Settings keeps its name", file: file, line: line)
        XCTAssertGreaterThan(help.width, 70, "Help keeps its name", file: file, line: line)
    }

    /// The last section sits above Settings, Help and the version.
    private func assertNothingCovered(file: StaticString = #filePath, line: UInt = #line) {
        let analytics = element("sidebar.section.analytics").frame
        XCTAssertFalse(analytics.isEmpty, "Analytics isn't in the sidebar", file: file, line: line)
        for identifier in ["sidebar.settings", "sidebar.help", "sidebar.version"] {
            let frame = element(identifier).frame
            XCTAssertGreaterThanOrEqual(frame.minY, analytics.maxY - 1, "\(identifier) at \(frame) covers Analytics at \(analytics)", file: file, line: line)
        }
    }

    /// Drags the window's bottom edge; it stops at the window's minimum.
    private func resizeWindow(toHeight height: CGFloat) {
        let window = app.windows.firstMatch
        let delta = height - window.frame.height
        guard abs(delta) > 1 else { return }
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 1))
        edge.click(forDuration: 0.2, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: delta)))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
