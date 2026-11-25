//
//  AddKeyCheckingUITests.swift
//  AtlasUITests
//

import XCTest

/// "Add Another Key…" while App Store Connect checks the new key
/// (`addkey-check`, the check never answers): its own step says the team
/// in use stays, and Cancel goes back to the filled form with no error.
@MainActor
final class AddKeyCheckingUITests: XCTestCase {
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

    func testCheckingStepCancelsBackToTheFilledForm() {
        app.launch(debugScene: "addkey-check")
        let title = element("addKey.checking.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: title), "Checking the new key…")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "stays as it is", "stays as it is"))
            .firstMatch.exists)

        element("addKey.checking.cancel").click()
        let connect = app.buttons["connect.connectButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertTrue(connect.isEnabled, "The form is still filled in")
        XCTAssertFalse(element("addKey.checking").exists)
        XCTAssertFalse(element("addKey.done").exists, "Nothing was added")
    }

    func testConnectEndsOnTheDoneStep() {
        app.launch(debugScene: "addkey")
        let connect = app.buttons["connect.connectButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 20))
        connect.click()
        // The scene's check answers in 0.3 s: the step shows, then the done
        // step with Keep and Switch.
        XCTAssertTrue(element("addKey.done").waitForExistence(timeout: 10))
    }
}
