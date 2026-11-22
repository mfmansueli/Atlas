//
//  AssistantsUITests.swift
//  AtlasUITests
//

import XCTest

/// Settings → AI Assistants, opened by the `set-ai-*` and `set-assistants`
/// DEBUG scenes: the server switch, pairing an assistant, revoking one,
/// what assistants may suggest, and the activity. The scenes' server never
/// opens a port.
@MainActor
final class AssistantsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTurningTheServerOnOffersPairing() {
        launch(scene: "set-ai-off")
        let server = element("settings.ai.server")
        XCTAssertTrue(server.waitForExistence(timeout: 10))
        XCTAssertTrue(element("settings.ai.can").exists)
        XCTAssertTrue(element("settings.ai.cannot").exists)
        XCTAssertFalse(app.buttons["settings.ai.pair"].exists)

        if server.switches.firstMatch.exists {
            server.switches.firstMatch.click()
        } else {
            server.click()
        }

        let pair = app.buttons["settings.ai.pair"]
        XCTAssertTrue(pair.waitForExistence(timeout: 5))
        XCTAssertTrue(pair.isEnabled)
        XCTAssertTrue(element("settings.ai.noClients").exists)
    }

    func testThePairingSheetShowsASnippetPerClientAndACode() {
        launch(scene: "set-ai-pair")
        let snippet = element("settings.ai.pairSnippet")
        XCTAssertTrue(snippet.waitForExistence(timeout: 10))
        XCTAssertTrue(text(of: snippet).hasPrefix("claude mcp remove atlas --scope user"))
        XCTAssertTrue(text(of: snippet).contains("claude mcp add --scope user atlas -- "))
        XCTAssertTrue(text(of: snippet).contains("Contents/MacOS/atlas-mcp"))
        XCTAssertTrue(text(of: snippet).contains("al_pair_"))
        XCTAssertTrue(element("settings.ai.pairCode").exists)
        // The scene starts after Copy (never clicked here: it would write to
        // the clipboard), waiting for the client.
        XCTAssertTrue(element("settings.ai.pairWaiting").exists)
        XCTAssertEqual(app.buttons["settings.ai.pairCopy"].label, "Copied")

        app.radioButtons["Cursor"].firstMatch.click()
        XCTAssertTrue(waitForText(of: snippet) { $0.contains("\"url\": \"http://127.0.0.1:47321/mcp\"") })
        // Another client needs another command, so the wait starts over.
        XCTAssertFalse(element("settings.ai.pairWaiting").exists)
        XCTAssertEqual(app.buttons["settings.ai.pairCopy"].label, "Copy")

        app.radioButtons["Codex"].firstMatch.click()
        XCTAssertTrue(waitForText(of: snippet) { $0.hasPrefix("[mcp_servers.atlas]") })

        app.buttons["settings.ai.pairCancel"].click()
        XCTAssertTrue(snippet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("settings.ai.noClients").exists)
    }

    func testRevokingAnAssistantAsksFirst() {
        launch(scene: "set-ai-on")
        let cursor = element("settings.ai.client.cursor")
        XCTAssertTrue(cursor.waitForExistence(timeout: 10))
        XCTAssertTrue(element("settings.ai.client.claudeCode").exists)

        app.buttons["settings.ai.revoke.cursor"].click()
        let confirm = app.windows.descendants(matching: .button)["Revoke"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()

        XCTAssertTrue(cursor.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("settings.ai.client.claudeCode").exists)
    }

    func testProposalsCanBeTurnedOffOneByOne() {
        launch(scene: "set-ai-on")
        let prices = app.switches["settings.ai.allow.prices"]
        XCTAssertTrue(prices.waitForExistence(timeout: 10))
        XCTAssertEqual(prices.value as? Int, 1)
        prices.click()
        XCTAssertEqual(prices.value as? Int, 0)
        XCTAssertEqual(app.switches["settings.ai.allow.storeText"].value as? Int, 1)
        // Board 48's two newer switches.
        XCTAssertEqual(app.switches["settings.ai.allow.reviewReplies"].value as? Int, 1)
        XCTAssertEqual(app.switches["settings.ai.allow.artwork"].value as? Int, 1)
    }

    /// Show Activity… opens the log; the row says how many were refused.
    func testShowActivityOpensTheLog() {
        launch(scene: "set-assistants")
        let show = app.buttons["settings.ai.showActivity"]
        XCTAssertTrue(show.waitForExistence(timeout: 10))
        XCTAssertTrue(element("settings.ai.cannot").exists)
        show.click()
        XCTAssertTrue(app.buttons["settings.ai.activity.done"].waitForExistence(timeout: 5))
        app.buttons["settings.ai.activity.done"].click()
        XCTAssertTrue(app.buttons["settings.ai.activity.done"].waitForNonExistence(timeout: 5))
    }

    func testTheLogSaysWhyCallsWereRefused() {
        launch(scene: "set-ai-log")
        // Each log line reads as one element, its text as the value.
        let refusal = "so price proposals are off for this app"
        let reason = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", refusal, refusal))
            .firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 10))
        let clear = app.buttons["Clear"]
        XCTAssertTrue(clear.exists)
        clear.click()
        XCTAssertTrue(reason.waitForNonExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// Waits for the element's text to pass `check`, e.g. after another
    /// client is picked.
    private func waitForText(of element: XCUIElement, _ check: @escaping (String) -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in check(self.text(of: element)) }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5) == .completed
    }

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
}
