//
//  NominationsToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Nominations MCP tools on Lumen, Nov 24, 2026: `get_nominations`
/// reads what the section shows; `propose_nomination` waits as a
/// suggestion, checked like the person's own; `propose_nomination_submit`
/// and `propose_nomination_archive` ask, and never queue a Submit or
/// Archive row themselves.
@MainActor
@Suite("Nominations · MCP tools")
struct NominationsToolsTests {
    typealias Data = DebugNominationsData

    private let changes = ChangeQueue()
    private let store = NominationsStore()

    init() {
        store.load(Data.archive(), for: Data.lumen)
    }

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(changes: changes)
        let context = MCPToolContext(workspace: workspace, clientName: Data.client, allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private var newNomination: [String: JSONValue] {
        [
            "appId": "Lumen Journal",
            "name": "Lumen 2.0: Mood Calendar",
            "type": "APP_ENHANCEMENTS",
            "description": "A calendar of how your days felt, from the moods you already log.",
            "publishStartDate": "2027-02-02",
            "deviceFamilies": ["IPHONE", "IPAD"],
            "locales": ["en-US", "de-DE"],
            "supplementalMaterialsUris": ["https://lumen.app/press"],
            "why": "2.0 ships Feb 2, ten weeks out: editors ask for a few.",
            "confidence": 2,
        ]
    }

    @Test func getNominationsListsWhatTheSectionShows() async throws {
        let outcome = try await call(GetNominationsTool(store: store, now: { Data.now }), ["appId": "6450000001"])
        let nominations = try #require(outcome.result["nominations"]?.arrayValue)
        #expect(nominations.count == 3)
        let draft = try #require(nominations.first { $0["id"] == .string(Data.draftID) })
        #expect(draft["where"] == "thisMac")
        #expect(draft["state"] == "DRAFT")
        #expect(draft["type"] == "APP_ENHANCEMENTS")
        let winter = try #require(nominations.first { $0["id"] == .string(Data.winterID) })
        #expect(winter["state"] == "SUBMITTED")
        #expect(winter["where"] == "appStoreConnect")
        let submitted = try await call(GetNominationsTool(store: store, now: { Data.now }), ["appId": "Lumen Journal", "state": "submitted"])
        #expect(submitted.result["nominations"]?.arrayValue?.count == 1)
        let names: Set = ["get_nominations", "propose_nomination", "propose_nomination_submit", "propose_nomination_archive"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
    }

    @Test func aNewNominationWaitsAsASuggestion() async throws {
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), newNomination)
        #expect(outcome.result["status"] == "queued")
        let proposal = try #require(store.proposals(for: Data.lumen).first)
        #expect(proposal.isNew)
        #expect(proposal.client == Data.client)
        #expect(proposal.content.type == .appEnhancements)
        #expect(proposal.content.appIDs == [Data.lumen])
        #expect(proposal.evidence.layers?.confidence == .fairlySure)
        // Nothing is in Review & Push until the person accepts it.
        #expect(changes.changes(for: Data.lumen, section: .nominations).isEmpty)
        #expect(outcome.result["warning"] == nil)
    }

    @Test func proposingAgainReplacesYourOwn() async throws {
        _ = try await call(ProposeNominationTool(store: store, now: { Data.now }), newNomination)
        let again = try await call(ProposeNominationTool(store: store, now: { Data.now }), newNomination)
        #expect(again.result["replacedYourEarlierSuggestion"] == true)
        #expect(store.proposals(for: Data.lumen).count == 1)
    }

    @Test func whatAppleWouldRefuseIsRefusedWithReasons() async throws {
        var arguments = newNomination
        arguments["publishStartDate"] = "2026-11-20"
        arguments["description"] = "See https://lumen.app/mood for the film."
        arguments["inAppEventIds"] = ["nope"]
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), arguments)
        #expect(outcome.result["status"] == "refused")
        let reasons = outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(reasons.contains("The start date has passed. Pick one that hasn’t."))
        #expect(reasons.contains("The description has a link, which Apple refuses. Put links in supplementalMaterialsUris."))
        #expect(reasons.contains { $0.contains("“nope” isn’t one of the app’s In-App Events") })
        #expect(store.proposals(for: Data.lumen).isEmpty)
    }

    @Test func aNewNominationNeedsItsFields() async throws {
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), ["appId": "Lumen Journal", "why": "Soon."])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reasons"]?.arrayValue?.first == "Add a type, a name, a description, and a start date.")
    }

    @Test func aSubmittedNominationCantBeChanged() async throws {
        let arguments: [String: JSONValue] = ["appId": "Lumen Journal", "nominationId": .string(Data.winterID), "notes": "More.", "why": "Notes."]
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), arguments)
        #expect(outcome.result["status"] == "refused")
    }

    @Test func changesToADraftWaitOnIt() async throws {
        let arguments: [String: JSONValue] = [
            "appId": "Lumen Journal", "nominationId": .string(Data.draftID), "notes": "New notes.", "why": "Clearer for editors.",
        ]
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), arguments)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changes"] == ["notes"])
        #expect(outcome.result["warning"] != nil)
        #expect(store.proposals(for: Data.lumen).first?.nominationID == Data.draftID)
    }

    @Test func storeTextSwitchedOffRefusesEveryProposal() async throws {
        let outcome = try await call(ProposeNominationTool(store: store, now: { Data.now }), newNomination, allowed: [])
        #expect(outcome.result["status"] == "refused")
        let submit = try await call(
            ProposeNominationSubmitTool(store: store, now: { Data.now }),
            ["appId": "Lumen Journal", "nominationId": .string(Data.draftID), "why": "Ready."],
            allowed: []
        )
        #expect(submit.result["status"] == "refused")
    }

    @Test func askingToSubmitNeverQueuesTheSubmit() async throws {
        let outcome = try await call(
            ProposeNominationSubmitTool(store: store, now: { Data.now }),
            ["appId": "Lumen Journal", "nominationId": .string(Data.draftID), "why": "It starts in 9 days."]
        )
        #expect(outcome.result["status"] == "queued")
        #expect(store.actionRequests(for: Data.lumen, nominationID: Data.draftID).map(\.action) == [.submit])
        #expect(changes.changes(for: Data.lumen, section: .nominations).isEmpty)
    }

    @Test func aDraftThatIsntReadyCantBeAskedToSubmit() async throws {
        var archive = Data.archive()
        archive.drafts[0].content.description = ""
        store.load(archive, for: Data.lumen)
        let outcome = try await call(
            ProposeNominationSubmitTool(store: store, now: { Data.now }),
            ["appId": "Lumen Journal", "nominationId": .string(Data.draftID), "why": "Ready."]
        )
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reasons"]?.arrayValue?.first == "Add a description.")
    }

    @Test func archiveIsForSubmittedNominations() async throws {
        let tool = ProposeNominationArchiveTool(store: store, now: { Data.now })
        let draft = try await call(tool, ["appId": "Lumen Journal", "nominationId": .string(Data.draftID), "why": "Moved."])
        #expect(draft.result["status"] == "refused")
        let archived = try await call(tool, ["appId": "Lumen Journal", "nominationId": .string(Data.japanID), "why": "Over."])
        #expect(archived.result["status"] == "refused")
        let winter = try await call(tool, ["appId": "Lumen Journal", "nominationId": .string(Data.winterID), "why": "The week is over."])
        #expect(winter.result["status"] == "queued")
        #expect(store.actionRequests(for: Data.lumen, nominationID: Data.winterID).map(\.action) == [.archive])
        #expect(changes.changes(for: Data.lumen, section: .nominations).isEmpty)
    }

    @Test func anUnknownNominationIsRefused() async throws {
        let outcome = try await call(
            ProposeNominationSubmitTool(store: store, now: { Data.now }),
            ["appId": "Lumen Journal", "nominationId": "missing", "why": "Ready."]
        )
        #expect(outcome.result["status"] == "refused")
    }
}
