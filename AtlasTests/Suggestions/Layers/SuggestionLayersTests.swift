//
//  SuggestionLayersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Details, how sure and gloss beside a suggestion's why (README-DS §9):
/// read from a call, kept with the suggestion, and absent from data saved
/// before they existed.
@Suite("Suggestion layers")
struct SuggestionLayersTests {
    @Test func howSureHasTheFixedWords() {
        #expect(HowSure.allCases.map(\.word) == ["Not very sure", "Fairly sure", "Sure"])
        #expect(HowSure.allCases.map(\.steps) == [1, 2, 3])
        #expect(HowSure(rawValue: 0) == nil)
        #expect(HowSure(rawValue: 4) == nil)
    }

    @Test func emptyLayersAreNil() {
        #expect(SuggestionLayers().nonEmpty == nil)
        #expect(SuggestionLayers(details: "  ", gloss: "\n").nonEmpty == nil)
        #expect(SuggestionLayers(confidence: .sure).nonEmpty == SuggestionLayers(confidence: .sure))
        #expect(SuggestionLayers(details: " Every number. ").details == "Every number.")
    }

    @Test func aCallsLayersAreRead() throws {
        let arguments = MCPToolArguments(["details": "Every number.", "confidence": 2, "gloss": "Your week on one calm page"])
        #expect(try arguments.layers() == SuggestionLayers(details: "Every number.", confidence: .fairlySure, gloss: "Your week on one calm page"))
        #expect(try MCPToolArguments(["why": "Only a why."]).layers() == nil)
        #expect(throws: MCPToolError.self) { try MCPToolArguments(["confidence": 7]).layers() }
    }

    @Test func layersAreListedBesideTheReason() {
        var entry: [String: JSONValue] = ["reason": "Why."]
        SuggestionLayers(details: "D", confidence: .sure, gloss: "G").add(to: &entry)
        #expect(entry == ["reason": "Why.", "details": "D", "confidence": 3, "gloss": "G", "means": "G"])
    }

    @Test func aFieldSuggestionSavedBeforeLayersStillReads() throws {
        let suggestion = FieldSuggestion(
            id: "sg_1", appID: "1", target: SuggestionTarget(.storePage(locale: "en-US"), field: "subtitle"), value: "Private diary",
            reason: "Praised.", source: .assistant(client: "Claude Code"), layers: SuggestionLayers(confidence: .sure)
        )
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(suggestion)) as? [String: Any])
        json.removeValue(forKey: "layers")
        let old = try JSONDecoder().decode(FieldSuggestion.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.layers == nil)
        #expect(old.reason == "Praised.")
    }

    @Test func aFieldSuggestionKeepsItsLayers() throws {
        let suggestion = FieldSuggestion(
            id: "sg_1", appID: "1", target: SuggestionTarget(.storePage(locale: "de-DE"), field: "subtitle"), value: "Tagebuch",
            reason: "Shorter.", source: .assistant(client: "Claude Code"),
            layers: SuggestionLayers(details: "29 of 30 characters.", confidence: .notVerySure, gloss: "Diary"),
            createdAt: Date(timeIntervalSinceReferenceDate: 1000)
        )
        let decoded = try JSONDecoder().decode(FieldSuggestion.self, from: JSONEncoder().encode(suggestion))
        #expect(decoded == suggestion)
    }

    @Test func aFindingSavedBeforeDetailsStillReads() throws {
        let finding = AnalyticsFinding(
            id: "f", source: .assistant("Claude Code"), title: "Japan opens less", why: "4% open it.", sureness: "Sure",
            surenessDetail: "120 of 3,000", action: .retention
        )
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(finding)) as? [String: Any])
        json.removeValue(forKey: "details")
        let old = try JSONDecoder().decode(AnalyticsFinding.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.details == nil)
        var withDetails = finding
        withDetails.details = "Japan: 120 of 3,000; others 9%."
        #expect(try JSONDecoder().decode(AnalyticsFinding.self, from: JSONEncoder().encode(withDetails)).details == withDetails.details)
    }
}
