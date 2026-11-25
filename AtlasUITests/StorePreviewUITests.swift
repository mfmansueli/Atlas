//
//  StorePreviewUITests.swift
//  AtlasUITests
//

import XCTest

/// The App Store preview on Overview and Store Page (README-Redesign, “On
/// the App Store preview”): the App Preview, then every screenshot, and
/// the In-App Event card only while one is live, driven through the DEBUG
/// scenes `ov-event`, `sp-event`, `ov-preview` and `sp-preview-noapp`
/// (Lumen Journal; nothing leaves the Mac).
@MainActor
final class StorePreviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTheOverviewShowsTheLiveEventUnderTheScreenshotsAndOpensIt() {
        app.launch(debugScene: "ov-event")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        XCTAssertTrue(label(of: element("storePreview.shots"), becomes: "App Preview and 5 screenshots", timeout: 20))
        let event = element("storePreview.event")
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        XCTAssertTrue(event.label.hasPrefix("In-App Event happening now: Mood Calendar"), event.label)
        element("storePreview.part.event").click()
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
    }

    func testWithoutALiveEventThereIsNoCard() {
        app.launch(debugScene: "ov-preview")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        XCTAssertTrue(label(of: element("storePreview.shots"), becomes: "App Preview and 5 screenshots", timeout: 20))
        XCTAssertTrue(element("storePreview.shots.caption").exists)
        XCTAssertFalse(element("storePreview.event").exists)
    }

    func testClickingTheRowOpensScreenshots() {
        app.launch(debugScene: "ov-preview")
        XCTAssertTrue(element("workspace.overview").waitForExistence(timeout: 15))
        let row = element("storePreview.part.Screenshots")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(label(of: element("storePreview.shots"), becomes: "App Preview and 5 screenshots", timeout: 20))
        row.click()
        XCTAssertTrue(element("screenshots.root").waitForExistence(timeout: 15))
    }

    func testTheStorePageShowsTheLiveEventAndOpensInAppEvents() {
        app.launch(debugScene: "sp-event")
        let event = element("storePreview.event")
        XCTAssertTrue(event.waitForExistence(timeout: 20))
        XCTAssertTrue(label(of: element("storePreview.shots"), becomes: "App Preview and 5 screenshots", timeout: 20))
        element("storePreview.part.event").click()
        XCTAssertTrue(element("events.editor").waitForExistence(timeout: 15))
    }

    func testTheStorePageWithoutAnAppPreviewCountsScreenshotsOnly() {
        app.launch(debugScene: "sp-preview-noapp")
        let shots = element("storePreview.shots")
        XCTAssertTrue(shots.waitForExistence(timeout: 20))
        XCTAssertTrue(label(of: shots, becomes: "5 screenshots", timeout: 20))
        XCTAssertFalse(element("storePreview.event").exists)
        element("storePreview.part.Screenshots").click()
        XCTAssertTrue(element("screenshots.root").waitForExistence(timeout: 15))
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
