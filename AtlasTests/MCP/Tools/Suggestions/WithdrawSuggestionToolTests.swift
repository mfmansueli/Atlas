//
//  WithdrawSuggestionToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// An assistant's own `suggest_fields` suggestions that went stale: it
/// sends the field again to give it a new reason (the same value keeps its
/// id, `updated`), or takes it back with `withdraw_suggestion`. Alba, Nov
/// 19: sg_7 suggested releasing after approval "so it's out by Nov 23",
/// and the event then moved to Nov 26. Only the caller's open suggestions
/// go; the rest stay, with why.
@MainActor
@Suite("withdraw_suggestion and updated reasons")
struct WithdrawSuggestionToolTests {
    private let changes = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Information", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")

    private func context(_ client: String = "Claude Code") -> MCPToolContext {
        var services = DebugAppInformationServices()
        // Lumen's version releases manually here.
        services.hasOutdatedDetails = true
        var workspace = MCPTestFixtures.workspace(apps: [lumen], changes: changes, storePage: FakeStorePageServices(), appInformation: services)
        workspace.suggestions = store
        return MCPToolContext(workspace: workspace, clientName: client)
    }

    private func suggestRelease(
        _ value: String = "AFTER_APPROVAL", field: String = "release", reason: String, client: String = "Claude Code"
    ) async throws -> JSONValue {
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments([
            "appId": "Lumen Information",
            "items": [["area": "info", "page": "general", "field": .string(field), "value": .string(value), "reason": .string(reason)]],
        ]), in: context(client))
        return try #require(outcome.result["results"]?.arrayValue?.first)
    }

    private func withdraw(_ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Information"]
        all.merge(arguments) { $1 }
        return try await WithdrawSuggestionTool().call(MCPToolArguments(all), in: context(client))
    }

    // MARK: - suggest_fields again

    @Test func theSameValueWithANewReasonKeepsItsIdAndTakesTheReason() async throws {
        let first = try await suggestRelease(reason: "Release once approved, so the version is out when the streak starts on Nov 23.")
        #expect(first["status"] == "queued")
        let id = try #require(first["id"]?.stringValue)

        let again = try await suggestRelease(reason: "Release once approved, so the version is out when the streak starts on Nov 26.")
        #expect(again["status"] == "updated")
        #expect(again["id"] == .string(id))
        let suggestion = try #require(store.suggestion(id: id))
        #expect(suggestion.reason.hasSuffix("on Nov 26."))
        #expect(store.all(for: lumen.id).count == 1)

        // The same reason again changes nothing.
        let same = try await suggestRelease(reason: "Release once approved, so the version is out when the streak starts on Nov 26.")
        #expect(same["status"] == "unchanged")
    }

    @Test func anotherValueReplacesTheOpenOne() async throws {
        let first = try await suggestRelease(reason: "Out by Nov 23.")
        let replaced = try await suggestRelease("SCHEDULED", reason: "Out on Nov 26.")
        // Scheduling needs a date: refused, and the open one stays.
        if replaced["status"] == "refused" {
            #expect(store.suggestion(id: first["id"]?.stringValue ?? "") != nil)
        } else {
            #expect(replaced["status"] == "replaced")
            #expect(store.suggestion(id: first["id"]?.stringValue ?? "") == nil)
        }
    }

    // MARK: - withdraw_suggestion

    @Test func anAssistantWithdrawsItsOwnOpenSuggestion() async throws {
        let id = try #require(try await suggestRelease(reason: "Out by Nov 23.")["id"]?.stringValue)
        let outcome = try await withdraw(["id": .string(id)])
        #expect(outcome.result["status"] == "withdrawn")
        #expect(outcome.result["withdrawn"]?.arrayValue?.first?["id"] == .string(id))
        #expect(outcome.result["withdrawn"]?.arrayValue?.first?["field"] == "release")
        #expect(outcome.result["left"]?.arrayValue?.isEmpty == true)
        #expect(store.suggestion(id: id) == nil)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)
    }

    @Test func anotherAssistantsSuggestionIsLeftWithWhy() async throws {
        let id = try #require(try await suggestRelease(reason: "Out by Nov 23.", client: "Codex")["id"]?.stringValue)
        let outcome = try await withdraw(["ids": [.string(id), "sg_404"]])
        #expect(outcome.result["status"] == "unchanged")
        let left = try #require(outcome.result["left"]?.arrayValue)
        #expect(left.count == 2)
        #expect(left[0]["reason"] == "Suggested by Codex, not by you: left for the person.")
        #expect(left[1]["reason"] == "No suggestion with this id for Lumen Information.")
        #expect(store.suggestion(id: id) != nil)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
    }

    @Test func whatThePersonDecidedOnStays() async throws {
        let dismissed = try #require(try await suggestRelease(reason: "Out by Nov 23.")["id"]?.stringValue)
        store.dismiss([dismissed])
        let accepted = try #require(try await suggestRelease("© 2027 Northpier Studio", field: "copyright", reason: "A new year.")["id"]?.stringValue)
        let suggestion = try #require(store.suggestion(id: accepted))
        store.markAccepted(suggestion, previousValue: "© 2025 Northpier Studio")
        let outcome = try await withdraw(["ids": [.string(dismissed), .string(accepted)]])
        let reasons = outcome.result["left"]?.arrayValue?.compactMap { $0["reason"]?.stringValue } ?? []
        #expect(reasons.contains("The person dismissed it already."))
        #expect(reasons.contains { $0.hasPrefix("The person accepted it already") })
        #expect(store.suggestion(id: dismissed) != nil)
    }

    @Test func anIdIsNeeded() async throws {
        await #expect(throws: MCPToolError.self) { _ = try await withdraw([:]) }
    }

    @Test func theToolIsServedAndTheServerSaysWhenToUseIt() {
        #expect(MCPToolbox.standard.toolNames.contains("withdraw_suggestion"))
        #expect(WithdrawSuggestionTool().definition.changesState)
        #expect(MCPEndpoint.instructions.contains("withdraw_suggestion"))
        #expect(SuggestFieldsTool().definition.description.contains("updated"))
    }
}
#endif
