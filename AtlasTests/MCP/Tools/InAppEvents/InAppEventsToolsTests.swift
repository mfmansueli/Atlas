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
        _ tool: some MCPTool, _ arguments: [String: JSONValue], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases),
        events: [InAppEvent] = InAppEventsTestData.events, client: String = "Claude Code"
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace()
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: client, allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func text(_ locale: String, name: String = "Nome", short: String = "Curta", long: String = "Longa") -> JSONValue {
        ["locale": .string(locale), "name": .string(name), "shortDescription": .string(short), "longDescription": .string(long), "why": "Natural."]
    }

    @Test func theToolsAreInTheToolboxAndFree() {
        let names: Set = ["get_in_app_events", "propose_event_texts", "withdraw_event_texts"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        let refusals = names.compactMap { ProAssistantGate.refusal(forTool: $0, isPro: false) }
        #expect(refusals.isEmpty)
        #expect(GetInAppEventsTool().definition.isReadOnly)
        #expect(ProposeEventTextsTool().definition.proposalKind == .storeText)
        // Withdrawing touches only Atlas's own suggestions: no proposal
        // kind, so turning off store text proposals doesn't stop it.
        let withdraw = WithdrawEventTextsTool().definition
        #expect(withdraw.proposalKind == nil)
        #expect(!withdraw.isReadOnly)
        #expect(MCPEndpoint.instructions.contains("propose_event_texts"))
        #expect(MCPEndpoint.instructions.contains("withdraw_event_texts"))
        #expect(ProposeEventTextsTool().definition.description.contains("withdraw_event_texts"))
    }

    /// A suggestion waiting for a language App Store Connect has since
    /// written (in App Store Connect, or by a push) is stale.
    @Test func aSuggestionForALanguageWrittenSinceIsStale() async throws {
        store.add([Data.suggestion("de-DE"), Data.suggestion("ja")], for: Data.app.id)
        let tool = GetInAppEventsTool(store: store, directory: EventArtworkTestFiles.directory())
        let before = try #require(try await call(tool, ["appId": "Lumen Journal"]).result["events"]?.arrayValue?.first)
        let open = try #require(before["openSuggestions"]?.arrayValue)
        #expect(open.compactMap { $0["locale"]?.stringValue } == ["de-DE", "ja"])
        #expect(open.allSatisfy { $0["stale"] == false })
        #expect(open[0]["by"] == "Claude Code")
        #expect(open[0]["name"] == "Name")
        #expect(open[0]["shortDescription"] == "Short de-DE")
        #expect(open[0]["suggestedAt"]?.stringValue?.isEmpty == false)
        #expect(before["staleSuggestions"]?.arrayValue?.isEmpty == true)

        var winter = Data.winter
        winter.localizations[1].shortDescription = "Drei Zeilen"
        winter.localizations[1].longDescription = "Drei Zeilen am Tag."
        let events = [winter] + Data.events.dropFirst()
        let after = try #require(try await call(tool, ["appId": "Lumen Journal"], events: events).result["events"]?.arrayValue?.first)
        #expect(after["staleSuggestions"]?.arrayValue == ["de-DE"])
        #expect(after["openSuggestions"]?.arrayValue?.first?["stale"] == true)
        #expect(after["openSuggestions"]?.arrayValue?.last?["stale"] == false)
        // `suggestedLanguages` stays as it was.
        #expect(after["suggestedLanguages"]?.arrayValue?.contains("de-DE") == true)
    }

    /// An assistant takes back only its own suggestions; another's stay for
    /// the person.
    @Test func withdrawRemovesOnlyTheCallersOwnSuggestions() async throws {
        var other = Data.suggestion("pt-BR")
        other.source = "Codex"
        store.add([Data.suggestion("de-DE"), Data.suggestion("ja"), other], for: Data.app.id)

        let outcome = try await call(WithdrawEventTextsTool(store: store), [
            "appId": "Lumen Journal", "eventId": "winter", "locales": ["de-DE", "pt-BR", "fr-FR", "de-DE"],
        ])
        #expect(outcome.result["status"] == "withdrawn")
        #expect(outcome.result["withdrawn"]?.arrayValue == ["de-DE"])
        let left = try #require(outcome.result["left"]?.arrayValue)
        #expect(left.compactMap { $0["locale"]?.stringValue } == ["pt-BR", "fr-FR"])
        #expect(left[0]["reason"]?.stringValue?.contains("Codex") == true)
        #expect(left[1]["reason"] == "No suggestion waits for this language.")
        #expect(store.open(for: Data.app.id, eventID: "winter").map(\.locale).sorted() == ["ja", "pt-BR"])
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)

        // "all" takes the rest of this client's; Codex's stays.
        let all = try await call(WithdrawEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "winter", "locales": ["all"]])
        #expect(all.result["withdrawn"]?.arrayValue == ["ja"])
        #expect(store.open(for: Data.app.id, eventID: "winter").map(\.locale) == ["pt-BR"])
        // Nothing of its own left: unchanged, not an error.
        let none = try await call(WithdrawEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "winter", "locales": ["all"]])
        #expect(none.result["status"] == "unchanged")
        #expect(none.isError == false)
        // Codex can take its own back.
        let codex = try await call(
            WithdrawEventTextsTool(store: store), ["appId": "Lumen Journal", "eventId": "winter", "locales": ["pt-BR"]], client: "Codex"
        )
        #expect(codex.result["withdrawn"]?.arrayValue == ["pt-BR"])
        #expect(store.count(for: Data.app.id) == 0)
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

    /// The art is designed like Autopilot's HTML pages: `design`
    /// carries the design project and how to make each piece, and asks for
    /// the look while Atlas doesn't have it.
    @Test func theArtIsDesignedFromTheAppsDesignProject() async throws {
        var project = DesignProject(kind: .claudeDesign, link: "Lumen Brand · Claude Design")
        project.summary = DesignSourceSummary(title: "Lumen Brand", colors: [DesignSwatch(name: "Dusk", hex: "#1F2E5C")], voice: "Calm")
        let autopilot = AutopilotCenter(designProjects: [Data.app.id: project])
        let outcome = try await call(GetInAppEventsTool(store: store, autopilot: autopilot), ["appId": "Lumen Journal"])
        let design = try #require(outcome.result["design"])
        #expect(design["how"]?.stringValue?.contains("HTML pages") == true)
        #expect(design["how"]?.stringValue?.contains("motion: true") == true)
        #expect(design["how"]?.stringValue?.contains("selfCheck") == true)
        #expect(design["artDirection"] == EventArtworkDirection.json)
        #expect(design["designProject"]?["source"] == "Lumen Brand · Claude Design")
        #expect(design["designProject"]?["summary"]?["colors"]?.arrayValue?.first?["hex"] == "#1F2E5C")
        #expect(design["designProject"]?["ifYouCantOpenIt"]?.stringValue?.hasPrefix("Don't stop") == true)
        #expect(design["lookMissing"]?.stringValue?.contains("report_app_support") == true)

        let without = try await call(GetInAppEventsTool(store: store, autopilot: AutopilotCenter()), ["appId": "Lumen Journal"])
        #expect(without.result["design"]?["designProject"] == nil)
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

    /// A free weekend is an event; a price isn't (Apple's In-App Events
    /// page, 2.3.13).
    @Test func aLanguageWithAPriceIsSkippedWithAppReviewsReason() async throws {
        let outcome = try await call(ProposeEventTextsTool(store: store), [
            "appId": "Lumen Journal", "eventId": "winter",
            "texts": [text("pt-BR", name: "Fim de Semana Grátis"), text("de-DE", short: "Alles für 4,99 €")],
        ])
        #expect(outcome.result["languages"]?.arrayValue == ["pt-BR"])
        let skipped = try #require(outcome.result["skipped"]?.arrayValue?.first)
        #expect(skipped["locale"] == "de-DE")
        #expect(skipped["reason"]?.stringValue?.hasPrefix("App Review rejects specific prices in In-App Event texts (Guideline 2.3.13): “4,99 €”.") == true)
        #expect(skipped["issues"]?.arrayValue?.first?["kind"] == "pricing")
        #expect(store.open(for: Data.app.id, eventID: "winter").map(\.locale) == ["pt-BR"])
    }

    @Test func getInAppEventsCarriesTheTextRules() async throws {
        let outcome = try await call(GetInAppEventsTool(store: store), ["appId": "Lumen Journal"])
        let rules = try #require(outcome.result["textRules"]?.arrayValue)
        #expect(rules.contains { $0.stringValue?.contains("Including specific pricing will lead to rejection by App Review.") == true })
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
