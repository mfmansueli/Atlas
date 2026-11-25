//
//  ImageLoadingUITests.swift
//  AtlasUITests
//

import XCTest

/// Images still on their way say so: the Overview's App Store preview,
/// driven through the `overview-shots-loading` DEBUG scene (Lumen
/// Journal's live screenshots take 8 seconds each to "download"; nothing
/// leaves the Mac).
@MainActor
final class ImageLoadingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheOverviewsScreenshotsLoadUntilTheyArrive() {
        app.launch(debugScene: "overview-shots-loading")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        let shots = element("storePreview.shots")
        XCTAssertTrue(shots.waitForExistence(timeout: 5))
        XCTAssertTrue(label(of: shots, becomes: "Loading screenshots", timeout: 3))
        // The App Preview first, then all five.
        XCTAssertTrue(label(of: shots, becomes: "App Preview and 5 screenshots", timeout: 60))
    }

    // MARK: - Helpers

    private func label(of target: XCUIElement, becomes text: String, timeout: TimeInterval) -> Bool {
        let says = NSPredicate(format: "label == %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: says, object: target)], timeout: timeout) == .completed
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
