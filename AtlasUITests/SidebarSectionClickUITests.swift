//
//  SidebarSectionClickUITests.swift
//  AtlasUITests
//

import XCTest

/// A click on each of the sidebar's sections opens it and the list shows
/// it selected, in a tall window and in one under 600 pt (27 pt rows). A
/// `.tag` placed under the rows' `onGeometryChange` once left every row
/// unselectable: clicks did nothing and no row showed selected, while
/// ⌘1–⌘9 still worked.
@MainActor
final class SidebarSectionClickUITests: XCTestCase {
    private var app: XCUIApplication!

    /// The sidebar's sections in its order (⌘1–⌘9), by their raw values:
    /// `sidebar.section.<id>` opens `workspace.<id>`.
    private static let sections = [
        "overview", "storePage", "screenshots", "productPages", "inAppEvents",
        "appInformation", "subscriptionPricing", "reviews", "analytics",
    ]

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testEachSectionOpensFromItsRowInATallWindow() {
        launchKeepingTheWindowHeight()
        resizeWindow(toHeight: 1100)
        XCTAssertGreaterThanOrEqual(app.windows.firstMatch.frame.height, 600, "The window didn't get taller than 600 pt.")
        clickEachSection("tall")
    }

    func testEachSectionOpensFromItsRowInAShortWindow() {
        launchKeepingTheWindowHeight()
        resizeWindow(toHeight: 0)
        XCTAssertLessThan(app.windows.firstMatch.frame.height, 600, "The window didn't get shorter than 600 pt.")
        clickEachSection("short")
    }

    // MARK: - Helpers

    /// Opens Overview and puts the window's height back afterwards: the
    /// window keeps its size for the next launch, the other tests' and the
    /// app's own.
    private func launchKeepingTheWindowHeight() {
        app.launch(debugScene: "nav-ov")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        let height = app.windows.firstMatch.frame.height
        addTeardownBlock { @MainActor [self] in
            resizeWindow(toHeight: height)
        }
    }

    /// Clicks every section's row, ending back on Overview, and checks the
    /// section opened and its row is the list's one selected row.
    private func clickEachSection(_ window: String, file: StaticString = #filePath, line: UInt = #line) {
        for section in Self.sections.dropFirst() + [Self.sections[0]] {
            let row = element("sidebar.section.\(section)")
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(window): no row for \(section)", file: file, line: line)
            XCTAssertTrue(row.isHittable, "\(window): \(section)'s row can't be clicked", file: file, line: line)
            row.click()
            XCTAssertTrue(
                element("workspace.\(section)").waitForExistence(timeout: 10),
                "\(window): a click on \(section)'s row didn't open it", file: file, line: line
            )
            assertSelected(section, window, file: file, line: line)
        }
    }

    /// The list selects one row, the section's: it shows highlighted.
    private func assertSelected(_ section: String, _ window: String, file: StaticString, line: UInt) {
        let selected = app.outlines["sidebar.sections"].outlineRows.matching(NSPredicate(format: "selected == true"))
        let one = expectation(for: NSPredicate(format: "count == 1"), evaluatedWith: selected)
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 5), .completed, "\(window): \(selected.count) rows selected", file: file, line: line)
        let rowFrame = selected.firstMatch.frame
        let sectionFrame = element("sidebar.section.\(section)").frame
        XCTAssertTrue(
            rowFrame.minY <= sectionFrame.midY && sectionFrame.midY <= rowFrame.maxY,
            "\(window): the selected row at \(rowFrame) isn't \(section)'s at \(sectionFrame)", file: file, line: line
        )
    }

    /// Drags the window's bottom edge; it stops at the window's minimum
    /// and at the screen's bottom.
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
