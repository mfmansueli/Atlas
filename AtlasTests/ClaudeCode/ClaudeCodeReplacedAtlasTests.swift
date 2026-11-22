//
//  ClaudeCodeReplacedAtlasTests.swift
//  AtlasTests
//

import Foundation
import Synchronization
import Testing
@testable import Atlas

/// A build written over the running Atlas (signed as "Atlas" instead of
/// com.lima.atlas): macOS won't run the helper for it, and says "you don't
/// have permission to view it". Atlas says to open it again instead, and
/// never offers to save the helper again or to try again.
@MainActor
@Suite("ClaudeCodeLauncher · Atlas replaced on disk")
struct ClaudeCodeReplacedAtlasTests {
    private let assistants = MCPTestFixtures.controller()
    private let runner = FakeUnixScriptRunner()
    private let identity = IdentityBox()
    private let launcher: ClaudeCodeLauncher

    /// What macOS says when the app on disk isn't the one asking.
    private static let permissionError = "The file “Start Claude Code.zsh” couldn’t be opened because you don’t have permission to view it."

    init() {
        launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner)
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: ClaudeCodeTestFixtures.lumenID)
        let identity = identity
        launcher.codeIdentity = { identity.value }
    }

    private func start() async -> ClaudeCodeRun.ID? {
        await launcher.start(.ask(area: "Subscriptions"), appID: ClaudeCodeTestFixtures.lumenID, appName: "Lumen Journal", prompt: "Suggest a subscription")
    }

    @Test func theHelperCheckSaysToOpenAtlasAgain() async {
        identity.value = ClaudeCodeTestFixtures.replacedAtlas
        await launcher.refreshHelper()
        #expect(launcher.helper == .atlasReplaced(onDisk: "Atlas"))
        // The helper isn't asked: macOS would refuse it.
        #expect(runner.recordedArguments.isEmpty)
        #expect(!launcher.canStart)
        #expect(launcher.helper.isInstalled)
        #expect(launcher.helper.installTitle == nil)
        #expect(launcher.helper.title == "Open Atlas again to start Claude Code")
        #expect(launcher.helper.detail.contains("“Atlas”"))
    }

    /// The button the person pressed shows why, instead of copying the
    /// prompt silently or failing with macOS's permission message.
    @Test func startingAfterAtlasWasReplacedEndsWithWhy() async throws {
        await launcher.refreshHelper()
        #expect(launcher.canStart)
        identity.value = ClaudeCodeTestFixtures.replacedAtlas

        let id = try #require(await start())
        let run = try #require(launcher.run(id))
        #expect(!run.isActive)
        #expect(run.failure == .atlasReplaced(onDisk: "Atlas"))
        #expect(run.failure?.canRetry == false)
        #expect(run.failure?.suggestsTerminal == false)
        #expect(launcher.helper == .atlasReplaced(onDisk: "Atlas"))
        #expect(runner.lastRunArguments == nil)
        #expect(assistants.pairedClients.isEmpty)

        // Again: the same answer, not a silent copy.
        let again = try #require(await start())
        #expect(launcher.run(again)?.failure == .atlasReplaced(onDisk: "Atlas"))
    }

    /// Replaced between the check and the run: macOS's refusal becomes the
    /// same answer.
    @Test func aRunMacOSRefusedAfterAtlasWasReplacedSaysWhy() async throws {
        await launcher.refreshHelper()
        runner.lines = []
        runner.losesExitLine = true
        runner.taskError = Self.permissionError
        let identity = identity
        runner.onRun = { arguments in
            if arguments.first == "run" { identity.value = ClaudeCodeTestFixtures.replacedAtlas }
        }

        let id = try #require(await start())
        await ClaudeCodeTestFixtures.waitForEnd(of: id, in: launcher)
        #expect(launcher.run(id)?.failure == .atlasReplaced(onDisk: "Atlas"))
        #expect(launcher.helper == .atlasReplaced(onDisk: "Atlas"))
    }

    /// The same refusal with Atlas as it was is still macOS's own words.
    @Test func aRefusedRunWithTheSameAtlasKeepsMacOSsMessage() async throws {
        await launcher.refreshHelper()
        runner.lines = []
        runner.losesExitLine = true
        runner.taskError = Self.permissionError

        let id = try #require(await start())
        await ClaudeCodeTestFixtures.waitForEnd(of: id, in: launcher)
        let failure = try #require(launcher.run(id)?.failure)
        #expect(failure == .couldNotStart(Self.permissionError))
        #expect(failure.canRetry)
    }

    @Test func openingAtlasAgainMakesItReady() async {
        identity.value = ClaudeCodeTestFixtures.replacedAtlas
        await launcher.refreshHelper()
        #expect(!launcher.canStart)

        identity.value = ClaudeCodeTestFixtures.signedAtlas
        await launcher.refreshHelper()
        #expect(launcher.canStart)
    }

    /// The identity the launcher reads, changed from the test or the
    /// pretend helper.
    private final class IdentityBox: Sendable {
        private let identity = Mutex(ClaudeCodeTestFixtures.signedAtlas)

        var value: AtlasCodeIdentity {
            get { identity.withLock { $0 } }
            set { identity.withLock { $0 = newValue } }
        }
    }
}
