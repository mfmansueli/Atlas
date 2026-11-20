//
//  EventTextRevisionToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_event_texts` with `revise`: an editable event's written
/// languages can be revised, with why; only the texts sent change, under
/// the same limits and App Review rules, and the result shows each change
/// against the current text. Alba, Nov 19: every long description said
/// "…by Sunday" and the event now ends on Wednesday, December 2.
@MainActor
@Suite("In-App Events MCP · text revisions")
struct EventTextRevisionToolTests {
    typealias Data = InAppEventsTestData
    typealias Streak = EventRevisionTestData

    private let store = InAppEventsStore()
    private let changes = ChangeQueue()

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], events: [InAppEvent] = [Streak.event()]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func revise(_ texts: JSONValue, revise: Bool? = true, events: [InAppEvent] = [Streak.event()]) async throws -> MCPToolOutcome {
        var arguments: [String: JSONValue] = ["appId": "Lumen Journal", "eventId": .string(Streak.eventID), "texts": texts]
        if let revise { arguments["revise"] = .bool(revise) }
        return try await call(ProposeEventTextsTool(store: store), arguments, events: events)
    }

    private func change(_ outcome: MCPToolOutcome, _ locale: String) throws -> JSONValue {
        let revised = try #require(outcome.result["revised"]?.arrayValue?.first { $0["locale"] == .string(locale) })
        return try #require(revised["changes"]?.arrayValue?.first)
    }

    private func skipped(_ outcome: MCPToolOutcome) -> [JSONValue] {
        outcome.result["skipped"]?.arrayValue ?? outcome.result["details"]?["skipped"]?.arrayValue ?? []
    }

    // MARK: - The real case

    @Test func albasLongDescriptionsAreRevisedInEveryLanguage() async throws {
        let outcome = try await revise(Streak.revisions())
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["languages"]?.arrayValue == ["en-US", "pt-BR", "de-DE"])
        #expect(skipped(outcome).isEmpty)
        #expect(outcome.result["revisedNote"]?.stringValue?.contains("the texts you left out stay as they are") == true)

        let english = try change(outcome, "en-US")
        #expect(english["field"] == "longDescription")
        #expect(english["now"] == .string(Streak.sunday["en-US"] ?? ""))
        #expect(english["suggested"] == .string(Streak.december["en-US"] ?? ""))
        #expect(english["marked"] == "Write one thank-you each evening and reach the 7-day streak milestone by [-Sunday-]{+December 2+}.")
        #expect(english["removed"]?.arrayValue == ["Sunday"])
        #expect(english["added"]?.arrayValue == ["December 2"])

        let portuguese = try change(outcome, "pt-BR")
        #expect(portuguese["marked"]?.stringValue?.hasSuffix("até [-domingo-]{+2 de dezembro+}.") == true)
        let german = try change(outcome, "de-DE")
        #expect(german["marked"]?.stringValue?.hasSuffix("bis [-Sonntag-]{+2. Dezember+}.") == true)

        // Only the long description is revised: the name and the short one stay.
        let kept = store.open(for: Data.app.id, eventID: Streak.eventID)
        #expect(kept.count == 3)
        #expect(kept.allSatisfy { $0.revisedFields == [.longDescription] && $0.name.isEmpty && $0.shortDescription.isEmpty })
        #expect(kept.allSatisfy { $0.why == Streak.why })
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)
    }

    @Test func reviseCanBeSetOnOneTextObject() async throws {
        let texts: JSONValue = [
            ["locale": "en-US", "revise": true, "longDescription": .string(Streak.december["en-US"] ?? ""), "why": .string(Streak.why)],
            ["locale": "pt-BR", "longDescription": .string(Streak.december["pt-BR"] ?? ""), "why": .string(Streak.why)],
        ]
        let outcome = try await revise(texts, revise: nil)
        #expect(outcome.result["languages"]?.arrayValue == ["en-US"])
        let refused = try #require(skipped(outcome).first)
        #expect(refused["locale"] == "pt-BR")
        #expect(refused["reason"]?.stringValue?.contains("revise: true") == true)
    }

    // MARK: - Refusals

    @Test func aWrittenLanguageWithoutReviseSaysHowToRevise() async throws {
        let outcome = try await revise(Streak.revisions(["en-US"]), revise: nil)
        #expect(outcome.result["status"] == "refused")
        let reason = try #require(skipped(outcome).first?["reason"]?.stringValue)
        #expect(reason.hasPrefix("This language is already written."))
        #expect(reason.contains("revise: true and why"))
    }

    @Test func aRevisionNeedsWhy() async throws {
        let outcome = try await revise([["locale": "en-US", "longDescription": .string(Streak.december["en-US"] ?? "")]])
        #expect(skipped(outcome).first?["reason"]?.stringValue?.hasPrefix("A revision needs why") == true)
        #expect(store.open(for: Data.app.id).isEmpty)
    }

    @Test func aRevisionOverAppleLimitIsRefusedWithItsCount() async throws {
        let long = String(repeating: "a", count: 121)
        let outcome = try await revise([["locale": "en-US", "longDescription": .string(long), "why": "Longer."]])
        #expect(skipped(outcome).first?["reason"] == "longDescription has 121 characters; it holds 120.")
        let name = try await revise([["locale": "en-US", "name": .string(String(repeating: "n", count: 31)), "why": "Longer."]])
        #expect(skipped(name).first?["reason"] == "name has 31 characters; it holds 30.")
    }

    @Test func aRevisionBreakingAppReviewsRulesIsRefusedWithTheReason() async throws {
        let outcome = try await revise([["locale": "de-DE", "shortDescription": "Alles für 4,99 €", "why": "A price."]])
        let refused = try #require(skipped(outcome).first)
        #expect(refused["reason"]?.stringValue?.hasPrefix("App Review rejects specific prices in In-App Event texts (Guideline 2.3.13)") == true)
        #expect(refused["issues"]?.arrayValue?.first?["kind"] == "pricing")
        #expect(store.open(for: Data.app.id).isEmpty)
    }

    @Test func onlyAWrittenLanguageCanBeRevised() async throws {
        let outcome = try await revise([["locale": "ja", "longDescription": "日曜日まで", "why": "Dates moved."]])
        #expect(skipped(outcome).first?["reason"]?.stringValue?.contains("isn’t written yet") == true)
    }

    @Test func theSameTextsAreNothingToRevise() async throws {
        let outcome = try await revise([["locale": "en-US", "longDescription": .string(Streak.sunday["en-US"] ?? ""), "why": "Same."]])
        #expect(skipped(outcome).first?["reason"]?.stringValue?.hasPrefix("These are its texts already") == true)
        let empty = try await revise([["locale": "en-US", "name": "", "why": "Empty."]])
        #expect(skipped(empty).first?["reason"]?.stringValue?.hasPrefix("name is empty") == true)
        let nothing = try await revise([["locale": "en-US", "why": "Nothing."]])
        #expect(skipped(nothing).first?["reason"]?.stringValue?.hasPrefix("Send the texts to change") == true)
    }

    @Test func anEventPastEditingCantBeRevised() async throws {
        let outcome = try await revise(Streak.revisions(["en-US"]), events: [Streak.event(state: .published)])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("can’t be changed any more") == true)
    }

    @Test func readyForReviewAndRejectedEventsCanBeRevised() async throws {
        for state in [InAppEventState.readyForReview, .rejected] {
            let outcome = try await revise(Streak.revisions(["en-US"]), events: [Streak.event(state: state)])
            #expect(outcome.result["status"] == "suggested", "\(state)")
        }
    }

    @Test func theChangeIsShownAgainstTheTextQueued() async throws {
        let event = Streak.event()
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        let localization = try #require(event.localization("en-US"))
        let queued = "Write one thank-you each evening and keep the streak going until Sunday."
        try changes.upsert(#require(builder.fieldChange(.longDescription, to: queued, in: localization, of: event, source: .you)))
        let outcome = try await revise(Streak.revisions(["en-US"]))
        let english = try change(outcome, "en-US")
        #expect(english["now"] == .string(queued))
    }

    // MARK: - get_in_app_events and withdraw_event_texts

    @Test func getInAppEventsShowsARevisionWithOnlyItsTexts() async throws {
        _ = try await revise(Streak.revisions(["en-US"]))
        let read = try await call(GetInAppEventsTool(store: store, now: { Data.now }), ["appId": "Lumen Journal", "include": ["texts"]])
        let event = try #require(read.result["events"]?.arrayValue?.first)
        let suggestion = try #require(event["openSuggestions"]?.arrayValue?.first)
        #expect(suggestion["revision"] == true)
        #expect(suggestion["revises"]?.arrayValue == ["longDescription"])
        #expect(suggestion["longDescription"] == .string(Streak.december["en-US"] ?? ""))
        #expect(suggestion["name"] == nil)
        #expect(suggestion["stale"] == false)
        // Once App Store Connect has the revised text, it's done: the read
        // takes it away, as In-App Events does.
        var written = Streak.event()
        written.localizations[0].longDescription = Streak.december["en-US"] ?? ""
        let later = try await call(GetInAppEventsTool(store: store, now: { Data.now }), ["appId": "Lumen Journal", "include": ["texts"]], events: [written])
        let open = later.result["events"]?.arrayValue?.first?["openSuggestions"]?.arrayValue ?? []
        #expect(!open.contains { $0["locale"] == "en-US" })
        #expect(!store.open(for: Data.app.id).contains { $0.locale == "en-US" && $0.isRevision })
    }

    @Test func withdrawEventTextsTakesRevisionsBack() async throws {
        _ = try await revise(Streak.revisions())
        let outcome = try await call(WithdrawEventTextsTool(store: store), [
            "appId": "Lumen Journal", "eventId": .string(Streak.eventID), "locales": ["en-US", "pt-BR"],
        ])
        #expect(outcome.result["withdrawn"]?.arrayValue == ["en-US", "pt-BR"])
        #expect(outcome.result["withdrawnRevisions"]?.arrayValue == ["en-US", "pt-BR"])
        #expect(store.open(for: Data.app.id).map(\.locale) == ["de-DE"])
        #expect(WithdrawEventTextsTool().definition.description.contains("revisions alike"))
    }

    @Test func theToolSaysHowToRevise() {
        let definition = ProposeEventTextsTool().definition
        #expect(definition.description.contains("revise: true"))
        #expect(definition.inputSchema["properties"]?["revise"]?["type"] == "boolean")
    }
}
