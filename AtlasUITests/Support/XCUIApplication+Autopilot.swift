//
//  XCUIApplication+Autopilot.swift
//  AtlasUITests
//

import XCTest

extension XCUIApplication {
    /// The Autopilot bar at the bottom of the section (board 80).
    var autopilotButton: XCUIElement {
        descendants(matching: .any).matching(identifier: "autopilotBar").firstMatch
    }

    /// The strip the closed bar grows above its field: its label is
    /// “Autopilot, ” and what happens.
    var autopilotStrip: XCUIElement {
        descendants(matching: .any).matching(identifier: "autopilotBar.strip").firstMatch
    }

    /// Opens the bar's More menu.
    func openAutopilotMenu() {
        let more = descendants(matching: .any).matching(identifier: "autopilotBar.more").firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "No More in the Autopilot bar")
        more.click()
    }

    /// The status line in the open More menu, “Claude Code · Connected”.
    /// NSMenu doesn't always keep SwiftUI's identifier (it can read
    /// `menuAction:`), so its “Name · state” title finds it too; a
    /// section's title (“Making screenshots · 5 of 10”) is disabled.
    var autopilotStatusItem: XCUIElement {
        let status = NSPredicate(
            format: "identifier == %@ OR (enabled == true AND title CONTAINS %@ AND NOT (title ENDSWITH %@))",
            "autopilotBar.status", " · ", "· Pro"
        )
        return menuItems.matching(status).firstMatch
    }

    /// The assistant's status popover, from the last line of More: what
    /// the Assistant button opened before.
    func openAssistantStatus() {
        openAutopilotMenu()
        let item = autopilotStatusItem
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No status item in the Autopilot bar's More")
        item.click()
    }

    /// The status line in More, “Claude Code · Connected”, read with the
    /// menu open and closed again.
    func assistantStatusTitle() -> String {
        openAutopilotMenu()
        let item = autopilotStatusItem
        _ = item.waitForExistence(timeout: 5)
        let title = item.title
        typeKey(.escape, modifierFlags: [])
        return title
    }
}
