//
//  InAppEventsToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_in_app_events` and `propose_event_texts`: what an assistant reads
/// of an app's events, and the languages it may suggest.
@MainActor
@Suite("In-App Events MCP tools")
struct InAppEventsToolsTests {
    typealias Data = InAppEventsTestData

    private let store = InAppEventsStore()

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace()
        workspace.services.inAppEvents = FakeInAppEventsServices()
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func text(_ locale: String, name: String = "Nome", short: String = "Curta", long: String = "Longa") -> JSONValue {
        ["locale": .string(locale), "name": .string(name), "shortDescription": .string(short), "longDescription": .string(long), "why": "Natural."]
    }

    @Test func theToolsAreInTheToolboxAndFree() {
        let names: Set = ["get_in_app_events", "propose_event_texts"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        let refusals = names.compactMap { ProAssistantGate.refusal(forTool: $0, isPro: false) }
        #expect(refusals.isEmpty)
        #expect(GetInAppEventsTool().definition.isReadOnly)
        #expect(ProposeEventTextsTool().definition.proposalKind == .storeText)
        #expect(MCPEndpoint.instructions.contains("propose_event_texts"))
    }

    @Test func eventsAreReadWithTheirTextsAndWhatIsMissing() async throws {
        store.add([Data.suggestion("ja")], for: Data.app.id)
        let outcome = try await call(GetInAppEventsTool(store: store), ["appId": "Lumen Journal"])
        let result = outcome.result
        #expect(result["limits"]?["name"] == .int(30))
        #expect(result["limits"]?["longDescription"] == .int(120))
        let events = try #require(result["events"]?.arrayValue)
        #expect(events.compactMap { $0["id"]?.stringValue } == ["winter", "update", "gratitude"])
        let winter = events[0]
        #expect(winter["editable"] == true)
        #expect(winter["badge"] == "CHALLENGE")
        #expect(winter["primaryLanguage"] == "en-US")
        #expect(winter["texts"]?["en-US"]?["name"] == "Winter Reflection Challenge")
        #expect(winter["suggestedLanguages"]?.arrayValue == ["ja"])
        // The sample store page's languages, less the one written whole and the one suggested.
        let missing = winter["missingLanguages"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(missing.contains("de-DE"))
        #expect(!missing.contains("en-US"))
        #expect(!missing.contains("ja"))
        #expect(events[2]["editable"] == false)
        #expect(events[2]["missingLanguages"]?.arrayValue?.isEmpty == true)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
    }

    @Test func textsBecomeSuggestionsForThePersonToAccept() async throws {
        let outcome = try await call(ProposeEventTextsTool(store: store), [
            "appId": "Lumen Journal", "eventId": "winter",
            "texts": [text("pt-BR", name: "Desafio de Fim de Ano"), text("de-DE"), text("xx-XX"), text("ja", short: String(repeating: "あ", count: 51))],
        ])
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["languages"]?.arrayValue == ["pt-BR", "de-DE"])
        let skipped = try #require(outcome.result["skipped"]?.arrayValue)
        #expect(skipped.compactMap { $0["locale"]?.stringValue } == ["xx-XX", "ja"])
        #expect(skipped[1]["reason"] == "shortDescription has 51 characters; it holds 50.")
        let kept = store.open(for: Data.app.id, eventID: "winter")
        #expect(kept.map(\.locale) == ["pt-BR", "de-DE"])
        #expect(kept[0].name == "Desafio de Fim de Ano")
        #expect(kept[0].source == "Claude Code")
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)
    }

    @Test func aLanguageAlreadyWrittenOrAnEventThatCantChangeIsRefused() async throws {
        let written = try await call(ProposeEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "winter", "texts": [text("en-US")]])
        #expect(written.result["status"] == "refused")
        let live = try await call(ProposeEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "update", "texts": [text("ja")]])
        #expect(live.result["status"] == "refused")
        let incomplete = try await call(ProposeEventTextsTool(store: store), [
            "appId": "Lumen Journal", "eventId": "winter", "texts": [text("ja", long: "")],
        ])
        #expect(incomplete.result["skipped"]?.arrayValue?.first?["reason"] == "longDescription is empty: send all three.")
        #expect(store.count(for: Data.app.id) == 0)
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "nope", "texts": [text("ja")]])
        }
    }

    @Test func proposingStoreTextCanBeTurnedOff() async throws {
        let outcome = try await call(
            ProposeEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "winter", "texts": [text("ja")]], allowed: [.prices]
        )
        #expect(outcome.result["status"] == "refused")
        #expect(store.count(for: Data.app.id) == 0)
    }
}
