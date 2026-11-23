//
//  ReleaseProposalListingTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Release proposals beside the other proposals: `list_proposals` lists
/// them with their status and reason, and `withdraw_suggestion` takes back
/// the caller's own by its rp- id, as `withdraw_release_action` does, on
/// Lumen Journal 1.4 approved and waiting to be released.
@MainActor
@Suite("Release proposals in list_proposals and withdraw_suggestion")
struct ReleaseProposalListingTests {
    private let fixtures = MCPReleaseFixtures(.pending)

    private func proposeRelease(client: String = "Claude Code") async throws -> String {
        let result = try await fixtures.propose("release", client: client)
        #expect(result["status"] == "queued")
        return try #require(result["proposalId"]?.stringValue)
    }

    private func list() async throws -> JSONValue {
        let outcome = try await ListProposalsTool(releaseProposals: fixtures.proposals)
            .call(MCPToolArguments(["appId": "Lumen"]), in: fixtures.context())
        return outcome.result
    }

    private func withdraw(_ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> JSONValue {
        var all: [String: JSONValue] = ["appId": "Lumen"]
        all.merge(arguments) { $1 }
        let outcome = try await WithdrawSuggestionTool(releaseProposals: fixtures.proposals)
            .call(MCPToolArguments(all), in: fixtures.context(client: client))
        return outcome.result
    }

    @Test func listProposalsListsThemWithStatusAndReason() async throws {
        let id = try await proposeRelease()
        let result = try await list()
        let release = try #require(result["releaseProposals"]?.arrayValue)
        #expect(release.count == 1)
        #expect(release.first?["proposalId"] == .string(id))
        #expect(release.first?["action"] == "release")
        #expect(release.first?["status"] == "pending")
        #expect(release.first?["reason"] == "Approved this morning; the event starts Friday.")
        #expect(release.first?["client"] == "Claude Code")
        // The screenshot proposals keep their key.
        #expect(result["proposals"]?.arrayValue != nil)
    }

    @Test func withoutReleaseProposalsTheKeyIsLeftOut() async throws {
        let result = try await list()
        #expect(result["releaseProposals"] == nil)
    }

    @Test func withdrawSuggestionTakesBackTheCallersOwnByItsID() async throws {
        let id = try await proposeRelease()
        let result = try await withdraw(["id": .string(id)])
        #expect(result["status"] == "withdrawn")
        #expect(result["withdrawn"]?.arrayValue?.first?["id"] == .string(id))
        #expect(result["withdrawn"]?.arrayValue?.first?["kind"] == "release")
        #expect(result["withdrawn"]?.arrayValue?.first?["action"] == "release")
        #expect(fixtures.proposals.proposal(id: id)?.status == .withdrawn)
        #expect(fixtures.proposals.pending(for: DebugFixtures.AppID.lumen).isEmpty)

        let listed = try await list()
        #expect(listed["releaseProposals"]?.arrayValue?.first?["status"] == "withdrawn")

        let again = try await withdraw(["id": .string(id)])
        #expect(again["status"] == "unchanged")
        #expect(again["left"]?.arrayValue?.first?["reason"]?.stringValue == "It doesn’t wait anymore.")
    }

    @Test func anotherAssistantsAndUnknownOnesAreLeftWithWhy() async throws {
        let id = try await proposeRelease(client: "Cursor")
        let result = try await withdraw(["ids": [.string(id), "rp-00000000"]])
        #expect(result["status"] == "unchanged")
        let left = try #require(result["left"]?.arrayValue)
        #expect(left.count == 2)
        #expect(left[0]["reason"]?.stringValue?.contains("Cursor") == true)
        #expect(left[1]["reason"]?.stringValue == "No release proposal with this id for this app.")
        #expect(fixtures.proposals.proposal(id: id)?.isPending == true)
    }

    @Test func fieldSuggestionsAndReleaseProposalsGoTogether() async throws {
        let id = try await proposeRelease()
        let result = try await withdraw(["ids": [.string(id), "sg_404"]])
        #expect(result["status"] == "withdrawn")
        #expect(result["withdrawn"]?.arrayValue?.count == 1)
        #expect(result["left"]?.arrayValue?.first?["id"] == "sg_404")
    }

    @Test func withdrawReleaseActionStillWorks() async throws {
        let id = try await proposeRelease()
        let result = try await fixtures.withdraw(["proposalId": .string(id)])
        #expect(result["status"] == "withdrawn")
        #expect(result["withdrawn"]?.arrayValue?.first?["proposalId"] == .string(id))
    }

    @Test func theToolsSayTheyTakeReleaseProposals() {
        #expect(ListProposalsTool().definition.description.contains("releaseProposals"))
        #expect(WithdrawSuggestionTool().definition.description.contains("rp-"))
        #expect(WithdrawSuggestionTool.isReleaseProposalID("rp-3f9a1c2e"))
        #expect(!WithdrawSuggestionTool.isReleaseProposalID("sg_7"))
    }
}
#endif
