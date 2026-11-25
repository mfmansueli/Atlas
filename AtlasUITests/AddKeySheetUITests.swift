//
//  AddKeySheetUITests.swift
//  AtlasUITests
//

import XCTest

/// "Add Another Key…" (`addkey`): the first launch's Connect in a sheet,
/// under the compact welcome header, with "Before you start" beside the
/// fields; the sheet stays inside its window, and Show Me How opens Atlas
/// Help from inside it.
@MainActor
final class AddKeySheetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func text(of element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    func testTheSheetIsTheWelcomeConnectForm() {
        app.launch(debugScene: "addkey")
        let steps = element("connect.steps")
        XCTAssertTrue(steps.waitForExistence(timeout: 20))
        XCTAssertTrue(element("welcome.header").exists, "The compact welcome header, not the old globe tile")
        XCTAssertEqual(text(of: element("connect.eyebrow")).uppercased(), "ANOTHER APP STORE CONNECT TEAM")
        XCTAssertEqual(text(of: element("connect.title")), "Add Another Key")
        XCTAssertTrue(element("connect.openAppStoreConnect").exists)
        XCTAssertTrue(element("connect.showMeHow").exists)
        XCTAssertTrue(app.textFields["connect.issuerIDField"].exists)
        XCTAssertFalse(app.staticTexts["Where do I find these?"].exists)
        XCTAssertTrue(app.buttons["connect.cancelButton"].exists)
        XCTAssertTrue(app.buttons["connect.connectButton"].exists)
        // Side by side, as the design draws it at 920 × 700.
        let fields = app.textFields["connect.issuerIDField"]
        XCTAssertGreaterThan(fields.frame.minX, steps.frame.maxX, "Then paste it here sits beside Before you start")
    }

    func testTheSheetStaysInsideTheWindow() {
        app.launch(debugScene: "addkey")
        let connect = app.buttons["connect.connectButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 20))
        let window = app.windows.firstMatch.frame
        let sheet = app.sheets.firstMatch.frame
        XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(sheet), "sheet \(sheet) in window \(window)")
        XCTAssertTrue(sheet.contains(connect.frame), "Connect isn't cut off")
    }

    func testShowMeHowOpensHelpFromTheSheet() {
        app.launch(debugScene: "addkey")
        let showMeHow = element("connect.showMeHow")
        XCTAssertTrue(showMeHow.waitForExistence(timeout: 20))
        // A plain button is a link to XCUITest.
        showMeHow.click()
        let title = element("help.article.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(text(of: title), "Connect to App Store Connect")
        XCTAssertTrue(app.buttons["connect.cancelButton"].exists, "The sheet stays open beside Help")
    }
}
