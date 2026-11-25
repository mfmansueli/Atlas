//
//  PaywallTrialReminderUITests.swift
//  AtlasUITests
//

import XCTest

/// The paywall's states by the canvas's names (`pw-*`), and the promise
/// after a trial starts: "Atlas reminds you 2 days before."
@MainActor
final class PaywallTrialReminderUITests: XCTestCase {
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

    func testTheTrialsDoneStepPromisesTheReminder() {
        app.launch(debugScene: "pw-done")
        let title = element("paywall.done.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertEqual(text(of: title), "Your free trial has started")
        let subtitle = text(of: element("paywall.done.subtitle"))
        XCTAssertTrue(subtitle.hasPrefix("You won’t be charged until "), subtitle)
        XCTAssertTrue(subtitle.hasSuffix("Atlas reminds you 2 days before."), subtitle)
        XCTAssertTrue(element("paywall.done.continue").exists)
    }

    func testEachLockOpensItsOwnCard() {
        app.launch(debugScene: "pw-price")
        let title = element("paywall.context.title")
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertTrue(text(of: title).hasSuffix("is part of Pro"), text(of: title))
    }

    func testLifetimeIsPickedFromTheToolbar() {
        app.launch(debugScene: "pw-life")
        let buy = app.buttons["paywall.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20))
        let lifetime = NSPredicate(format: "label == %@", "Buy Pro for $149.99")
        expectation(for: lifetime, evaluatedWith: buy)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(element("paywall.context.title").exists, "The toolbar's paywall has no card")
    }
}
