//
//  AssistantAskStarterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Requests the toolbar's Autopilot button sends with no asking button on
/// screen: started like one, copied when Claude Code can't start, and one
/// at a time for each app.
@MainActor
@Suite("AssistantAskStarter")
struct AssistantAskStarterTests {
    private let assistants = MCPTestFixtures.controller()
    private let runner = FakeUnixScriptRunner()
    private let app = StoreApp(id: ClaudeCodeTestFixtures.lumenID, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func center() -> AssistantAskCenter {
        let center = AssistantAskCenter()
        center.fly = { _, _, _ in false }
        center.announce = { _ in }
        return center
    }

    private var ask: WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(purpose: .ask(area: "Reviews"), prompt: "Draft replies", subject: "Reviews · replies", done: "Done.")
    }

    @Test func withoutTheHelperItCopiesTheRequest() async {
        runner.helperExists = false
        let launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner)
        await launcher.refreshHelper()
        let center = center()
        var copied: [String] = []
        let outcome = AssistantAskStarter.start(
            ask, app: app, client: "Claude Code", launcher: launcher, askCenter: center, reduceMotion: true
        ) { copied.append($0) }
        #expect(outcome == .copied)
        #expect(copied == ["Draft replies"])
        #expect(center.ask(for: app.id) == nil)
    }

    @Test func itSendsTheRequestAndStartsClaudeCode() async {
        let launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner)
        await launcher.refreshHelper()
        let center = center()
        let outcome = AssistantAskStarter.start(ask, app: app, client: "Claude Code", launcher: launcher, askCenter: center, reduceMotion: true)
        #expect(outcome == .sent)
        #expect(center.ask(for: app.id)?.subject == "Reviews · replies")
        #expect(center.ask(for: app.id)?.phase == .working)
        await ClaudeCodeTestFixtures.waitForHelper(runner)
        #expect(launcher.runs.last?.purpose == .ask(area: "Reviews"))

        // One request at a time for each app.
        let again = AssistantAskStarter.start(ask, app: app, client: "Claude Code", launcher: launcher, askCenter: center, reduceMotion: true)
        #expect(again == .busy)
    }
}
