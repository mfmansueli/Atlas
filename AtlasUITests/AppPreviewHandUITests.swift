//
//  AppPreviewHandUITests.swift
//  AtlasUITests
//

import XCTest

/// App Previews by hand on the Screenshots language page, on the DEBUG
/// scenes: the set with Choose App Previews…, each App Preview's menu
/// (Replace…, Move, Delete), a changed set waiting in Review & Push and a
/// refused video saying why.
@MainActor
final class AppPreviewHandUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AtlasDebugScene", scene, "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        return app
    }

    func testTheLanguagePageListsTheAppPreviews() {
        let app = launch("ap-hand")
        let choose = app.buttons["screenshots.appPreviews.choose"]
        XCTAssertTrue(choose.waitForExistence(timeout: 20))
        XCTAssertTrue(choose.isEnabled, "One live App Preview leaves room for 2")
        let menu = app.descendants(matching: .any)["screenshots.appPreviews.menu.1"]
        XCTAssertTrue(menu.exists)
        menu.click()
        XCTAssertTrue(app.menuItems["Replace…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Delete"].exists)
        XCTAssertFalse(app.menuItems["Move Left"].isEnabled, "The first can't go left")
        app.typeKey(.escape, modifierFlags: [])
        attach(app, "ap-hand")
    }

    func testAChangedSetIsFullAndSaysWhatGoes() {
        let app = launch("ap-hand-changed")
        let choose = app.buttons["screenshots.appPreviews.choose"]
        XCTAssertTrue(choose.waitForExistence(timeout: 20))
        XCTAssertFalse(choose.isEnabled, "A set takes 3")
        XCTAssertTrue(app.descendants(matching: .any)["screenshots.appPreviews.tile.3"].exists)
        attach(app, "ap-hand-changed")
    }

    func testARefusedVideoSaysWhy() {
        let app = launch("ap-hand-problem")
        let alert = app.dialogs.firstMatch.exists ? app.dialogs.firstMatch : app.sheets.firstMatch
        XCTAssertTrue(app.staticTexts["These App Previews can’t go in the set"].waitForExistence(timeout: 20) || alert.exists)
        attach(app, "ap-hand-problem")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }
}
