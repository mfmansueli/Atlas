//
//  MCPServerControllerConnectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A token no pairing has is remembered as "can't connect" until an
/// assistant gets in with its pairing's token, and the connection for an
/// app compares the folder each session works in with the app's.
@MainActor
@Suite("MCP · connection per app")
struct MCPServerControllerConnectionTests {
    private let clock = TestClock()
    private let controller: MCPServerController
    private let client: MCPPairedClient
    private let token: String
    private let launcher: ClaudeCodeLauncher

    init() {
        controller = MCPTestFixtures.controller(clock: clock)
        (client, token) = MCPTestFixtures.pair(in: controller, at: clock.now)
        launcher = ClaudeCodeTestFixtures.launcher(assistants: controller, clock: clock)
    }

    private func refuse(token: String = "al_pair_old", userAgent: String? = "claude-code/2.1.316") async throws {
        let headers = userAgent.map { ["User-Agent": $0] } ?? [:]
        let body = MCPTestFixtures.rpc("initialize", params: MCPTestFixtures.initializeParams())
        let request = MCPTestFixtures.request(token: token, body: body, headers: headers)
        #expect(try #require(await controller.handle(request).response).status == 401)
    }

    @Test func anOldTokenIsRememberedAsCantConnect() async throws {
        try await refuse()
        #expect(controller.refusedConnection == MCPRefusedConnection(date: clock.now, clientName: "Claude Code"))
        let connection = try #require(controller.connection(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", launcher: launcher))
        #expect(connection.state == .refused(date: clock.now, client: "Claude Code"))
        #expect(connection.title == "Claude Code can’t connect")
    }

    @Test func thePairingsOwnTokenFixesIt() async throws {
        try await refuse(userAgent: nil)
        #expect(controller.refusedConnection?.clientName == nil)
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        #expect(controller.refusedConnection == nil)
    }

    /// A run Atlas started gets in with its own token: that says nothing
    /// about the person's registration.
    @Test func aRunGettingInDoesntFixIt() async throws {
        try await refuse()
        let runToken = controller.issueRunToken(for: client.id)
        _ = try await MCPTestFixtures.initialize(controller, token: runToken)
        #expect(controller.refusedConnection != nil)
    }

    @Test func anEndedRunsGoodbyeIsntCantConnect() async throws {
        let runToken = controller.issueRunToken(for: client.id)
        controller.revokeRunToken(runToken)
        try await refuse(token: runToken)
        #expect(controller.refusedConnection == nil)
    }

    @Test func theAppsFolderTellsHereFromAnotherProject() async throws {
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: DebugFixtures.AppID.lumen)
        launcher.setProjectFolder("/Users/sam/Developer/Tempo", for: DebugFixtures.AppID.tempo)
        launcher.rememberApp(DebugFixtures.AppID.tempo, name: "Tempo Metronome")
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        controller.sessions[0].workingDirectory = "~/Developer/Tempo"

        let lumen = try #require(controller.connection(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", launcher: launcher))
        #expect(lumen.appFolder == "~/Developer/Lumen")
        #expect(lumen.state == .connectedElsewhere(folder: "~/Developer/Tempo", appName: "Tempo Metronome"))
        let tempo = try #require(controller.connection(appID: DebugFixtures.AppID.tempo, appName: "Tempo Metronome", launcher: launcher))
        #expect(tempo.state == .connectedHere(folder: "~/Developer/Tempo"))
    }

    /// Claude Code in Alba kept its first token after SimProps's setup
    /// paired a second one: both projects are connected at once, each on
    /// its own card.
    @Test func everyPairingOfTheAssistantCountsSoSeveralProjectsAreConnected() async throws {
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: DebugFixtures.AppID.lumen)
        launcher.setProjectFolder("/Users/sam/Developer/Tempo/", for: DebugFixtures.AppID.tempo)
        launcher.rememberApp(DebugFixtures.AppID.tempo, name: "Tempo Metronome")
        let (_, newerToken) = MCPTestFixtures.pair(in: controller, at: clock.now)
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        _ = try await MCPTestFixtures.initialize(controller, token: newerToken)
        controller.sessions[0].workingDirectory = "~/Developer/Lumen"
        controller.sessions[1].workingDirectory = "~/Developer/Tempo"

        let lumen = try #require(controller.connection(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", launcher: launcher))
        #expect(lumen.state == .connectedHere(folder: "~/Developer/Lumen"))
        let tempo = try #require(controller.connection(appID: DebugFixtures.AppID.tempo, appName: "Tempo Metronome", launcher: launcher))
        #expect(tempo.state == .connectedHere(folder: "~/Developer/Tempo"))
        #expect(tempo.appFolder == "~/Developer/Tempo")
    }

    @Test func anotherAssistantsSessionsDontCount() async throws {
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: DebugFixtures.AppID.lumen)
        let (_, cursorToken) = MCPTestFixtures.pair(.cursor, in: controller, at: clock.now)
        _ = try await MCPTestFixtures.initialize(controller, token: cursorToken, clientName: "cursor")
        controller.sessions[0].workingDirectory = "~/Developer/Lumen"
        // Claude Code connects last, so the card is about it either way.
        clock.advance(by: 60)
        _ = try await MCPTestFixtures.initialize(controller, token: token)

        let lumen = try #require(controller.connection(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", launcher: launcher))
        #expect(lumen.clientName == "Claude Code")
        #expect(lumen.state == .connectedUnsure(folder: nil))
    }

    @Test func anAppWithoutAFolderAsksForIt() async throws {
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        controller.sessions[0].workingDirectory = "~/Developer/Lumen"
        let lumen = try #require(controller.connection(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", launcher: launcher))
        #expect(lumen.state == .connectedUnsure(folder: "~/Developer/Lumen"))
        #expect(lumen.actions == [.chooseFolder])
    }
}
