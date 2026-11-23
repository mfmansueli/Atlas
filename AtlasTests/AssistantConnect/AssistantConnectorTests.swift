//
//  AssistantConnectorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Connect stands on: the pairing each assistant connects as, Claude
/// Code's registration through the helper, Disconnect…, Send a Test
/// Suggestion, and the rows' words.
@MainActor
@Suite("AssistantConnector")
struct AssistantConnectorTests {
    private let clock = TestClock()
    private let assistants: MCPServerController
    private let runner = FakeUnixScriptRunner()
    private let launcher: ClaudeCodeLauncher
    private let config = InMemoryAssistantConfig()
    private let apps = PretendAssistantApps(installed: [.cursor])
    private let connector: AssistantConnector

    init() {
        assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock)
        connector = AssistantConnector(config: config, apps: apps, folders: AssistantProjectFolders(defaults: nil))
        connector.claudeCodeFound = { false }
    }

    // MARK: - Pairings

    @Test func connectMakesOnePairingAndReusesIt() throws {
        let first = try #require(assistants.connectionCredentials(for: .cursor))
        let again = try #require(assistants.connectionCredentials(for: .cursor))
        #expect(first.clientID == again.clientID)
        #expect(first.token == again.token)
        #expect(assistants.pairedClients.count == 1)
        #expect(assistants.pairedClient(of: .cursor)?.name == "Cursor")
    }

    @Test func aPairingWithoutItsTokenGetsANewOne() throws {
        let client = MCPPairedClient(id: UUID(), kind: .claudeDesktop, name: "Claude Desktop", pairedAt: clock.now)
        assistants.restorePairings([client], tokens: [:])
        let credentials = try #require(assistants.connectionCredentials(for: .claudeDesktop))
        #expect(credentials.clientID == client.id)
        #expect(assistants.tokens[client.id] == credentials.token)
    }

    @Test func disconnectRevokesAndTakesAtlasOut() throws {
        let credentials = try #require(assistants.connectionCredentials(for: .cursor))
        try config.addAtlas(to: .cursor, token: credentials.token, bridgePath: "/atlas-mcp")
        connector.didConnect(.init(assistant: .cursor, appID: "1", appName: "Lumen Journal", folder: nil))
        connector.disconnect(.cursor, server: assistants, launcher: launcher)
        #expect(assistants.pairedClient(of: .cursor) == nil)
        #expect(assistants.tokens[credentials.clientID] == nil)
        #expect(config.token(of: .cursor) == nil)
        #expect(connector.fresh == nil)
    }

    // MARK: - Claude Code's registration

    @Test func registeringRemovesTheOldEntryThenAddsTheBridge() async {
        await launcher.refreshHelper()
        let problem = await launcher.registerAtlas(token: "al_t", bridgePath: "/A/atlas-mcp")
        #expect(problem == nil)
        let runs = runner.recordedArguments.filter { $0.first == "run" }
        #expect(runs.count == 2)
        #expect(Array(runs[0].suffix(5)) == ["mcp", "remove", "atlas", "--scope", "user"])
        #expect(Array(runs[1].suffix(9)) == ["mcp", "add", "--scope", "user", "atlas", "--", "/A/atlas-mcp", "--token", "al_t"])
        #expect(runs[1][1] == ProjectFolderPath.home)
    }

    @Test func aFailedRegistrationSaysWhatClaudeCodeSaid() async {
        runner.lines = ["MCP server atlas already exists in user config"]
        runner.exitStatus = 1
        await launcher.refreshHelper()
        let problem = await launcher.registerAtlas(token: "al_t", bridgePath: "/A/atlas-mcp")
        #expect(problem == "MCP server atlas already exists in user config")
    }

    @Test func withoutTheHelperThereIsNoRegistration() async {
        runner.helperExists = false
        await launcher.refreshHelper()
        let problem = await launcher.registerAtlas(token: "al_t", bridgePath: "/A/atlas-mcp")
        #expect(problem == "Helper not installed")
        #expect(runner.recordedArguments.allSatisfy { $0.first != "run" })
    }

    // MARK: - Found on this Mac

    @Test func installedAssistantsAreFound() async {
        #expect(connector.isInstalled(.cursor, launcher: launcher))
        #expect(!connector.isInstalled(.claudeForMac, launcher: launcher))
        #expect(!connector.isInstalled(.claudeCode, launcher: nil))
        // The helper found Claude Code.
        await launcher.refreshHelper()
        #expect(connector.isInstalled(.claudeCode, launcher: launcher))
    }

    // MARK: - Send a Test Suggestion

    @Test func theTestAsksClaudeCodeWithAtlasToolsOnly() async throws {
        runner.lines = [
            ClaudeCodeTestFixtures.initLine(),
            ClaudeCodeTestFixtures.toolUseLine("mcp__atlas__suggest_fields", id: "t1"),
            ClaudeCodeTestFixtures.resultLine(text: "Suggested a subtitle."),
        ]
        await launcher.refreshHelper()
        await connector.sendTest(.claudeCode, appID: ClaudeCodeTestFixtures.lumenID, appName: "Lumen Journal", launcher: launcher)
        #expect(connector.tests[.claudeCode] == .arrived)
        let run = try #require(launcher.runs.last)
        #expect(run.purpose == .test)
        #expect(run.prompt.contains("test sent from Settings"))
    }

    @Test func anAssistantAtlasCantAskGetsThePromptCopied() async {
        var copied: [String] = []
        connector.copy = { copied.append($0) }
        await connector.sendTest(.cursor, appID: "1", appName: "Lumen Journal", launcher: launcher)
        #expect(connector.tests[.cursor] == .copied)
        #expect(copied.first?.hasPrefix("Suggest a better subtitle for Lumen Journal") == true)
    }

    // MARK: - The rows' words

    @Test func lastUsedSaysTodayOrTheDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 15)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 10, minute: 43)))
        let october = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 10)))
        #expect(ConnectableAssistantRow.lastUsed(nil, now: now, calendar: calendar) == "not used yet")
        #expect(ConnectableAssistantRow.lastUsed(today, now: now, calendar: calendar).hasPrefix("last used today at "))
        let older = ConnectableAssistantRow.lastUsed(october, now: now, calendar: calendar)
        #expect(older.hasPrefix("last used ") && older.contains("Oct") && older.contains("22"))
    }

    @Test func eachAssistantConnectsAsItsPairingKind() {
        #expect(ConnectableAssistant.claudeCode.clientKind == .claudeCode)
        #expect(ConnectableAssistant.claudeForMac.clientKind == .claudeDesktop)
        #expect(ConnectableAssistant(clientKind: .cursor) == .cursor)
        #expect(ConnectableAssistant(clientKind: .codex) == nil)
        #expect(ConnectableAssistant.cursor.configFolder == ".cursor")
        #expect(ConnectableAssistant.claudeForMac.configFileName == "claude_desktop_config.json")
    }
}
