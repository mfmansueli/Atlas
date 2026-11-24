//
//  SidebarFooterFitUITests.swift
//  AtlasUITests
//

import XCTest

/// The sidebar's footer never covers a section: in a window too short for
/// Settings, Show the Tour and Atlas Help as rows, they fold into a row of
/// icons, and they come back as rows when the window grows.
@MainActor
final class SidebarFooterFitUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheFooterFoldsInAShortWindowAndNeverCoversASection() {
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
        XCTAssertGreaterThan(settings.frame.width, 150, "Tall: Settings is a row with its name")
        assertNothingCovered()

        resizeWindow(toHeight: 0)
        XCTAssertLessThan(window.frame.height, 700, "The window didn't get shorter.")
        let folded = expectation(for: NSPredicate(format: "frame.size.width < 150"), evaluatedWith: settings)
        wait(for: [folded], timeout: 5)
        XCTAssertEqual(abs(settings.frame.midY - element("sidebar.help").frame.midY), 0, accuracy: 1, "Folded: one row of icons")
        assertNothingCovered()

        resizeWindow(toHeight: 820)
        let unfolded = expectation(for: NSPredicate(format: "frame.size.width > 150"), evaluatedWith: settings)
        wait(for: [unfolded], timeout: 5)
    }

    // MARK: - Helpers

    /// The last section sits above Settings, the tour and Help, none under
    /// another.
    private func assertNothingCovered(file: StaticString = #filePath, line: UInt = #line) {
        let analytics = element("sidebar.section.analytics").frame
        XCTAssertFalse(analytics.isEmpty, "Analytics isn't in the sidebar", file: file, line: line)
        for identifier in ["sidebar.settings", "sidebar.showTour", "sidebar.help", "sidebar.version"] {
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
