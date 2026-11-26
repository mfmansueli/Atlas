//
//  ToolbarItemFitUITests.swift
//  AtlasUITests
//

import XCTest

/// The workspace toolbar's items keep the width of what they say. AppKit
/// fixed each item's width when it laid the toolbar out, so an item that had
/// been squeezed (the window at its minimum, a status read late) stayed
/// narrow: “Suggest Ever…” cut, “R 3” for Review & Push, and the section's
/// status spilling to the left under the sidebar button.
@MainActor
final class ToolbarItemFitUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testItemsGetTheirWidthBackAfterTheMinimumWindow() {
        app.launch(debugScene: "nav-ov")
        let reviewPush = element("workspace.reviewPushButton")
        XCTAssertTrue(reviewPush.waitForExistence(timeout: 15))
        restoresTheOpenedWidth()
        resizeWindow(toWidth: Self.defaultWidth)
        wait(seconds: 1)
        let reviewPushWidth = reviewPush.frame.width

        resizeWindow(toWidth: 600)
        wait(seconds: 1)
        // At the bottom it folds only under 700 pt, narrower than the
        // window goes (board 80).
        XCTAssertEqual(reviewPush.frame.width, reviewPushWidth, accuracy: 1, "Review & Push keeps its label at the minimum.")

        resizeWindow(toWidth: Self.defaultWidth)
        wait(seconds: 1)
        XCTAssertEqual(reviewPush.frame.width, reviewPushWidth, accuracy: 1, "Review & Push has its label again.")
        assertTheTitleIsBesideTheSidebarButton()
        attach("toolbar after the minimum")
    }

    func testChangingTextsKeepTheirItemsAsWideAsTheyWant() {
        app.launch(debugScene: "tb-text")
        let step = element("tbText.step")
        XCTAssertTrue(step.waitForExistence(timeout: 15))
        // Every step twice: growing, shrinking and growing again.
        for round in 1...2 {
            for number in 1...5 {
                let shows = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "Step \(number) of", "Step \(number) of")
                let reached = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: shows, object: step)], timeout: 10)
                XCTAssertEqual(reached, .completed, "Step \(number)")
                wait(seconds: 1)
                assertEveryItemIsAsWideAsItWants("round \(round), step \(number)")
            }
        }
    }

    // MARK: - Helpers

    /// The window's `.defaultSize` width.
    private static let defaultWidth: CGFloat = 1200

    /// The title, its status and the button as wide as the scene
    /// measured them, and the title right of the sidebar button.
    private func assertEveryItemIsAsWideAsItWants(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let ideal = text(of: element("tbText.idealWidths")).split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(ideal.count, 2, "The scene measured its items", file: file, line: line)
        guard ideal.count == 2 else { return }
        let title = element("workspace.title").frame
        let status = element("workspace.status").frame
        XCTAssertGreaterThanOrEqual(max(title.width, status.width), ideal[0] - 4, "Title cut at \(name)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element("tbText.button").frame.width, ideal[1] - 4, "Button cut at \(name)", file: file, line: line)
        assertTheTitleIsBesideTheSidebarButton(file: file, line: line)
    }

    /// Not under the sidebar button, where an item too narrow for it put it.
    private func assertTheTitleIsBesideTheSidebarButton(file: StaticString = #filePath, line: UInt = #line) {
        let toggle = sidebarToggle
        guard toggle.exists else { return XCTFail("No sidebar button", file: file, line: line) }
        for identifier in ["workspace.title", "workspace.status"] {
            let frame = element(identifier).frame
            XCTAssertGreaterThanOrEqual(
                frame.minX, toggle.frame.maxX - 1, "\(identifier) at \(frame) is under the sidebar button at \(toggle.frame)",
                file: file, line: line
            )
        }
    }

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

    /// The window's own button that shows and hides the sidebar.
    private var sidebarToggle: XCUIElement {
        let named = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "sidebar", "toggleSidebar")
        return app.windows.firstMatch.toolbars.buttons.matching(named).firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
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
