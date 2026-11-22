//
//  XCUIApplication+Autopilot.swift
//  AtlasUITests
//

import XCTest

extension XCUIApplication {
    /// The toolbar's Autopilot split button (board 57).
    var autopilotButton: XCUIElement {
        descendants(matching: .any).matching(identifier: "workspace.autopilot").firstMatch
    }

    /// Opens the Autopilot button's menu with a click on its arrow.
    func openAutopilotMenu() {
        let button = autopilotButton
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).click()
    }

    /// The status line in the open Autopilot menu, “Claude Code ·
    /// Connected”. NSMenu doesn't always keep SwiftUI's identifier (it can
    /// read `menuAction:`), so its “Name · state” title finds it too; a
    /// section's title (“Making screenshots · 5 of 10”) is disabled.
    var autopilotStatusItem: XCUIElement {
        let status = NSPredicate(
            format: "identifier == %@ OR (enabled == true AND title CONTAINS %@ AND NOT (title ENDSWITH %@))",
            "workspace.autopilot.status", " · ", "· PRO"
        )
        return menuItems.matching(status).firstMatch
    }

    /// The assistant's status popover, from the last line of Autopilot's
    /// menu: what the Assistant button opened before.
    func openAssistantStatus() {
        openAutopilotMenu()
        let item = autopilotStatusItem
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No status item in the Autopilot menu")
        item.click()
    }

    /// The status line in the Autopilot menu, “Claude Code · Connected”,
    /// read with the menu open and closed again.
    func assistantStatusTitle() -> String {
        openAutopilotMenu()
        let item = autopilotStatusItem
        _ = item.waitForExistence(timeout: 5)
        let title = item.title
        typeKey(.escape, modifierFlags: [])
        return title
    }
}
