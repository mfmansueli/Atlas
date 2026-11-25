//
//  LoadingStatesUITests.swift
//  AtlasUITests
//

import XCTest

/// Data on its way from App Store Connect shows a static grey skeleton
/// shaped like what arrives, and VoiceOver reads "Loading <what>" once
/// for it. Each test opens a DEBUG scene that holds its read for a day
/// (`LoadingDebugScenes`; nothing leaves the Mac).
@MainActor
final class LoadingStatesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testOverviewShowsItsCardsLoading() {
        expectSkeleton(scene: "overview-loading", identifier: "overview.skeleton", label: "Loading the overview")
    }

    func testScreenshotsShowTheirSetsLoading() {
        expectSkeleton(scene: "shots-loading", identifier: "screenshots.loading", label: "Loading the screenshots")
    }

    func testInAppPurchaseTextsShowTheirTableLoading() {
        expectSkeleton(scene: "texts-loading", identifier: "storePage.inAppTexts.loading", label: "Loading the In-App Purchase texts")
    }

    func testInAppEventsShowTheirCardsLoading() {
        expectSkeleton(scene: "ev-loading", identifier: "events.loading", label: "Loading the In-App Events")
    }

    func testNominationsShowTheirCardsLoading() {
        expectSkeleton(scene: "ft-loading", identifier: "nominations.loading", label: "Loading the nominations")
    }

    func testAppInformationShowsItsPageLoading() {
        expectSkeleton(scene: "info-loading", identifier: "appInformation.loading", label: "Loading App Information")
    }

    func testTheAssetLibraryShowsItsFilesLoading() {
        expectSkeleton(scene: "assets-loading", identifier: "assetLibrary.loading", label: "Loading the Asset Library")
    }

    func testThePaywallShowsItsPlansLoading() {
        expectSkeleton(scene: "paywall-loading", identifier: "paywall.loading", label: "Loading the plans")
    }

    func testTheLibraryShowsTheSidebarLoading() {
        expectSkeleton(scene: "lib-loading", identifier: "sidebar.loading", label: "Loading your apps")
    }

    // MARK: - Helpers

    /// The scene's skeleton is there, one element with its label and
    /// nothing to press, and still there a moment later.
    private func expectSkeleton(scene: String, identifier: String, label: String, file: StaticString = #filePath, line: UInt = #line) {
        app.launch(debugScene: scene)
        let skeleton = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(skeleton.waitForExistence(timeout: 15), "\(identifier) in \(scene)", file: file, line: line)
        XCTAssertEqual(skeleton.label, label, file: file, line: line)
        XCTAssertEqual(skeleton.buttons.count, 0, "nothing to press on a skeleton", file: file, line: line)
        sleep(1)
        XCTAssertTrue(skeleton.exists, "\(identifier) stays while the read is held", file: file, line: line)
    }
}
