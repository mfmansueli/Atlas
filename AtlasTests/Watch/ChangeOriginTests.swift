//
//  ChangeOriginTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A Look for Improvements run's proposals carry its id: from the run's
/// token, through the tool context, onto the suggestion, and saved
/// suggestions from before still read.
@MainActor
@Suite("Look for Improvements · run origin")
struct ChangeOriginTests {
    private typealias Data = WatchTestData
    private let runID = UUID()

    @Test func anOriginSurvivesJSON() throws {
        let origin = ChangeOrigin.watch(runID: runID)
        #expect(try JSONDecoder().decode(ChangeOrigin.self, from: JSONEncoder().encode(origin)) == origin)
        #expect(origin.watchRunID == runID)
    }

    private func suggestion(origin: ChangeOrigin?) throws -> FieldSuggestion {
        let store = FieldSuggestionStore(now: { Data.now })
        let german = try #require(StoreLocaleCatalog.locale(code: "de-DE"))
        return store.add(
            appID: Data.lumen, target: .storePage(german, .whatsNew), value: "Neu", reason: "Commits", source: .assistant(client: "Claude Code"),
            origin: origin
        ).suggestion
    }

    @Test func aSuggestionKeepsItsOrigin() throws {
        let tagged = try suggestion(origin: .watch(runID: runID))
        #expect(tagged.origin == .watch(runID: runID))
        let decoded = try JSONDecoder().decode(FieldSuggestion.self, from: JSONEncoder().encode(tagged))
        #expect(decoded == tagged)
        #expect(try suggestion(origin: nil).origin == nil)
    }

    @Test func aSuggestionSavedBeforeOriginsStillReads() throws {
        let tagged = try suggestion(origin: .watch(runID: runID))
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(tagged)) as? [String: Any])
        #expect(object["origin"] != nil)
        object["origin"] = nil
        let old = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(FieldSuggestion.self, from: old)
        #expect(decoded.origin == nil)
        #expect(decoded.id == tagged.id)
        #expect(decoded.value == tagged.value)
    }

    @Test func aRunTokenCarriesItsOriginUntilItsRevoked() {
        let assistants = MCPTestFixtures.controller()
        let (client, pairing) = MCPTestFixtures.pair(in: assistants, at: Data.now)
        let token = assistants.issueRunToken(for: client.id, origin: .watch(runID: runID))
        let plain = assistants.issueRunToken(for: client.id)
        #expect(assistants.origin(forAuthorization: "Bearer \(token)") == .watch(runID: runID))
        #expect(assistants.origin(forAuthorization: "Bearer \(plain)") == nil)
        #expect(assistants.origin(forAuthorization: "Bearer \(pairing)") == nil)
        #expect(assistants.origin(forAuthorization: nil) == nil)
        assistants.revokeRunToken(token)
        #expect(assistants.origin(forAuthorization: "Bearer \(token)") == nil)
        #expect(assistants.runOrigins.isEmpty)
        #expect(assistants.runTokens[plain] == client.id)
    }

    @Test func aWatchRunsTokenCarriesTheRunsID() async throws {
        let clock = TestClock(Data.now)
        let runner = FakeUnixScriptRunner()
        runner.exitStatus = nil
        let assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        let launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock)
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: Data.lumen)
        await launcher.refreshHelper()
        let id = try #require(await launcher.start(.watch, appID: Data.lumen, appName: "Lumen Journal", prompt: "Look"))
        #expect(launcher.run(id)?.purpose == .watch)
        #expect(Array(assistants.runOrigins.values) == [.watch(runID: id)])
        launcher.stop(id)
        await ClaudeCodeTestFixtures.waitForEnd(of: id, in: launcher)
        #expect(assistants.runOrigins.isEmpty)
    }

    @Test func otherRunsCarryNoOrigin() async throws {
        let clock = TestClock(Data.now)
        let runner = FakeUnixScriptRunner()
        runner.exitStatus = nil
        let assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        let launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock)
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: Data.lumen)
        await launcher.refreshHelper()
        let id = try #require(await launcher.start(.suggestEverything, appID: Data.lumen, appName: "Lumen Journal", prompt: "Suggest"))
        #expect(assistants.runOrigins.isEmpty)
        #expect(!assistants.runTokens.isEmpty)
        launcher.stop(id)
        await ClaudeCodeTestFixtures.waitForEnd(of: id, in: launcher)
    }

    @Test func theWatchPurposeReadsTheProject() {
        #expect(ClaudeCodeRunPurpose.watch.permissions == .readProject)
        #expect(!ClaudeCodeRunPurpose.watch.title.isEmpty)
    }
}
