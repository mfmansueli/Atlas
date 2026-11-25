//
//  AgeRatingOverrideToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_age_rating`'s override on Lumen's sample (calculated 4+):
/// "Rate higher than calculated" with a reason waits until the person
/// accepts it; a rating not above the answers or no reason is refused.
@MainActor
@Suite("propose_age_rating · override")
struct AgeRatingOverrideToolTests {
    private let services = DebugAppInformationServices()
    private let changes = ChangeQueue()

    private func context() -> MCPToolContext {
        MCPToolContext(workspace: MCPTestFixtures.workspace(changes: changes, appInformation: services), clientName: "Claude Code")
    }

    private func propose(_ override: JSONValue) async throws -> JSONValue {
        let outcome = try await ProposeAgeRatingTool().call(MCPToolArguments(["appId": "Lumen", "override": override]), in: context())
        return try #require(outcome.result["results"]?.arrayValue?.first)
    }

    @Test func getAgeRatingListsTheOverrides() async throws {
        let outcome = try await GetAgeRatingTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        #expect(outcome.result["calculated"] == "4+")
        #expect(outcome.result["override"] == .null)
        #expect(outcome.result["overrides"] == ["9+", "13+", "16+", "18+"])
    }

    @Test func anOverrideWithItsReasonWaitsForThePerson() async throws {
        let result = try await propose(["rating": "13+", "reason": "Entries talk about grief and self-harm."])
        #expect(result["status"] == "queued")
        let change = try #require(changes.change(id: result["changeId"]?.stringValue ?? ""))
        #expect(change.newValue == "13+ · Entries talk about grief and self-harm.")
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.awaitingAcceptance != nil)
        #expect(services.notes.notes(for: "6450000001").overrideReason == "Entries talk about grief and self-harm.")
    }

    @Test func aRatingNotAboveTheAnswersOrNoReasonIsRefused() async throws {
        let low = try await propose(["rating": "4+", "reason": "Calm app."])
        #expect(low["status"] == "refused")
        #expect(low["reason"]?.stringValue?.contains("9+") == true)
        let noReason = try await propose(["rating": "16+"])
        #expect(noReason["status"] == "refused")
        let off = try await propose(["rating": "off"])
        #expect(off["status"] == "unchanged")
        #expect(changes.changes(for: "6450000001").isEmpty)
    }

    @Test func neitherAnswersNorAnOverrideIsAnError() async throws {
        await #expect(throws: (any Error).self) {
            try await ProposeAgeRatingTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        }
    }
}
#endif
