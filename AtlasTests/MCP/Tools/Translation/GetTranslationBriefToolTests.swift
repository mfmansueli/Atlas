//
//  GetTranslationBriefToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_translation_brief`: one language's source texts, limits, glossary
/// and market, and the suggestions to review, nothing about the others.
@MainActor
@Suite("get_translation_brief")
struct GetTranslationBriefToolTests {
    private let store = FieldSuggestionStore()
    private let app = StorePageContentFixtures.app

    private func brief(_ arguments: [String: JSONValue], glossary: TranslationGlossary = TranslationGlossary()) async throws -> JSONValue {
        var workspace = MCPTestFixtures.workspace(apps: [app], storePage: FakeStorePageServices(), glossary: glossary)
        workspace.suggestions = store
        var all = arguments
        all["appId"] = "app1"
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        return try await GetTranslationBriefTool().call(MCPToolArguments(all), in: context).result
    }

    private func field(_ name: String, in result: JSONValue) -> JSONValue? {
        result["fields"]?.arrayValue?.first { $0["field"]?.stringValue == name }
    }

    @Test func germanGetsTheSourceTheLimitsAndItsOwnTexts() async throws {
        let result = try await brief(["locale": "de-DE"])
        #expect(result["locale"]?["code"] == "de-DE")
        #expect(result["sourceLocale"]?["code"] == "en-US")
        let subtitle = try #require(field("subtitle", in: result))
        #expect(subtitle["source"] == "Private notes, gentle prompts")
        #expect(subtitle["current"] == "Private Notizen, sanfte Fragen")
        #expect(subtitle["missing"] == false)
        #expect(subtitle["limit"] == ["max": 30, "unit": "characters"])
        #expect(field("name", in: result)?["limit"] == ["max": 30, "unit": "characters"])
        #expect(field("promotionalText", in: result)?["limit"] == ["max": 170, "unit": "characters"])
        #expect(field("description", in: result)?["limit"] == ["max": 4000, "unit": "characters"])
        #expect(field("whatsNew", in: result)?["limit"] == ["max": 4000, "unit": "characters"])
        #expect(field("promotionalText", in: result)?["missing"] == true)
    }

    @Test func keywordsAndURLsAreMarked() async throws {
        let result = try await brief(["locale": "de-DE"])
        let keywords = try #require(field("keywords", in: result))
        #expect(keywords["kind"] == "keywords")
        #expect(keywords["limit"] == ["max": 100, "unit": "bytes"])
        #expect(keywords["note"]?.stringValue?.contains("no space after a comma") == true)
        let support = try #require(field("supportUrl", in: result))
        #expect(support["kind"] == "url")
        #expect(support["copyAsIs"] == true)
        #expect(result["keywordRules"]?.stringValue?.contains("100 bytes") == true)
    }

    @Test func theGlossaryKeepsTheAppNameAndTheTerms() async throws {
        let glossary = TranslationGlossary(terms: ["Lumen Plus", "Face ID", "lumen journal"], tone: .playful)
        let result = try await brief(["locale": "de-DE"], glossary: glossary)
        #expect(result["glossary"]?["keep"] == ["Lumen Journal", "Lumen Plus", "Face ID"])
        #expect(result["tone"] == "playful")
        #expect(result["write"]?.stringValue?.contains("never word for word") == true)
        #expect(result["market"]?.stringValue?.contains("du or Sie") == true)
        #expect(result["storeTextRules"]?.arrayValue?.isEmpty == false)
    }

    @Test func approvedTextsAndOpenSuggestionsAreThisLanguagesOnly() async throws {
        let mine = SuggestionSource.assistant(client: "Claude Code")
        let accepted = store.add(appID: app.id, target: .storePage(.german, .whatsNew), value: "Wöchentliche Rückblicke.", reason: "", source: mine)
        store.markAccepted(accepted.suggestion, previousValue: "")
        store.add(appID: app.id, target: .storePage(.german, .keywords), value: "tagebuch,stimmung", reason: "", source: mine)
        store.add(appID: app.id, target: .storePage(.englishUS, .keywords), value: "diary,mood", reason: "", source: mine)

        let result = try await brief(["locale": "de-DE", "fields": ["keywords", "whatsNew"], "run": "run_4"])
        #expect(result["glossary"]?["approvedHere"]?.arrayValue?.map { $0["value"] } == ["Wöchentliche Rückblicke."])
        let open = try #require(result["openSuggestions"]?.arrayValue)
        #expect(open.map { $0["value"] } == ["tagebuch,stimmung"])
        #expect(result["fields"]?.arrayValue?.map { $0["field"] } == ["keywords", "whatsNew"])
        #expect(result["run"] == "run_4")
    }

    @Test func captionsAddTheirSteps() async throws {
        let result = try await brief(["locale": "de-DE", "fields": ["captions"]])
        #expect(result["fields"]?.arrayValue?.isEmpty == true)
        #expect(result["captions"]?.stringValue?.contains("measure_caption") == true)
    }

    @Test func theSourceLanguageAndUnknownOnesAreRefused() async {
        await #expect(throws: MCPToolError.self) { try await brief(["locale": "en-US"]) }
        await #expect(throws: MCPToolError.self) { try await brief(["locale": "fr-FR"]) }
        await #expect(throws: MCPToolError.self) { try await brief(["locale": "de-DE", "fields": ["tagline"]]) }
    }
}
