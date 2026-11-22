//
//  MCPServerControllerGlintTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The first-time glint (effect 6) is armed when an assistant connects for
/// the first time: as the pairing sheet closes, or on the first request of
/// a client paired without the sheet open.
@MainActor
@Suite("MCP first connection glint")
struct MCPServerControllerGlintTests {
    private let clock = TestClock()
    private let secrets = InMemorySecretStore()
    private let defaults = MCPTestFixtures.defaults()
    private let controller: MCPServerController

    init() {
        controller = MCPTestFixtures.controller(secrets: secrets, defaults: defaults, clock: clock)
    }

    private func freshGlint() throws -> FirstConnectionGlint {
        let name = "MCPServerControllerGlintTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return FirstConnectionGlint(defaults: defaults)
    }

    @Test func thePairingSheetArmsItAsItCloses() async throws {
        let glint = try freshGlint()
        controller.firstConnectionGlint = glint
        controller.beginPairing()
        let token = try #require(controller.pendingPairing?.token)

        _ = try await MCPTestFixtures.initialize(controller, token: token)
        // Connected, but the sheet still shows it: not yet.
        #expect(controller.pendingPairing?.isConnected == true)
        #expect(!glint.isArmed)

        controller.finishPairing()
        #expect(glint.isArmed)
    }

    @Test func aSheetClosedBeforeTheClientConnectedArmsItOnItsFirstRequest() async throws {
        let glint = try freshGlint()
        controller.firstConnectionGlint = glint
        controller.beginPairing()
        let token = try #require(controller.pendingPairing?.token)
        controller.finishPairingWithoutTesting()
        #expect(!glint.isArmed)

        _ = try await MCPTestFixtures.initialize(controller, token: token)
        #expect(glint.isArmed)
    }

    @Test func aClientSeenBeforeNeverArmsIt() async throws {
        controller.firstConnectionGlint = try freshGlint()
        controller.beginPairing()
        let token = try #require(controller.pendingPairing?.token)
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        controller.finishPairing()

        let later = try freshGlint()
        controller.firstConnectionGlint = later
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        #expect(!later.isArmed)
    }

    @Test func onceShownOnThisMacItIsNeverArmedAgain() async throws {
        let glint = try freshGlint()
        glint.markShown()
        controller.firstConnectionGlint = glint
        controller.beginPairing()
        let token = try #require(controller.pendingPairing?.token)
        _ = try await MCPTestFixtures.initialize(controller, token: token)
        controller.finishPairing()
        #expect(!glint.isArmed)
    }
}
