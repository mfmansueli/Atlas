//
//  ProposeNominationDeleteToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_nomination_delete` on Lumen, Nov 24, 2026: a draft App Store
/// Connect has waits as its Delete row until the person accepts it; a
/// submitted nomination or a draft on this Mac is refused.
@MainActor
@Suite("propose_nomination_delete")
struct ProposeNominationDeleteToolTests {
    typealias Data = DebugNominationsData

    private static let remoteDraftID = "nom-remote-draft"
    private let changes = ChangeQueue()
    private let store = NominationsStore()

    init() {
        store.load(Data.archive(), for: Data.lumen)
    }

    private func call(_ nominationID: String) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        var remoteDraft = Data.draft
        remoteDraft.id = Self.remoteDraftID
        remoteDraft.content.name = "Lumen 1.4: Faster search"
        workspace.services.nominations = DebugNominationsServices(nominations: Data.remote + [remoteDraft])
        let context = MCPToolContext(workspace: workspace, clientName: Data.client)
        let tool = ProposeNominationDeleteTool(store: store, now: { Data.now })
        return try await tool.call(MCPToolArguments([
            "appId": "Lumen Journal", "nominationId": .string(nominationID), "why": "A newer draft covers the same launch.",
        ]), in: context)
    }

    @Test func aRemoteDraftWaitsUntilThePersonAccepts() async throws {
        let outcome = try await call(Self.remoteDraftID)
        #expect(outcome.result["status"] == "queued")
        let id = NominationChangeBuilder.changeID(.delete, nominationID: Self.remoteDraftID)
        #expect(outcome.result["changeId"] == .string(id))
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: Data.client))
        #expect(change.awaitingAcceptance != nil)
        #expect(change.layers?.details == "A newer draft covers the same launch.")
        let again = try await call(Self.remoteDraftID)
        #expect(again.result["status"] == "unchanged")
    }

    @Test func aSubmittedNominationOrADraftOnThisMacIsRefused() async throws {
        let submitted = try await call(Data.winterID)
        #expect(submitted.result["status"] == "refused")
        #expect(submitted.result["reason"]?.stringValue?.contains("propose_nomination_archive") == true)
        let local = try await call(Data.draftID)
        #expect(local.result["status"] == "refused")
        #expect(changes.changes(for: Data.lumen, section: .nominations).isEmpty)
    }
}
