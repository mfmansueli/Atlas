//
//  BeginTranslationToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `begin_translation`: each language's fields, a writer and a reviewer
/// prompt per language, and a run Atlas counts by language;
/// `end_suggestions` with a locale ends one language.
@MainActor
@Suite("begin_translation")
struct BeginTranslationToolTests {
    private let store = FieldSuggestionStore()
    private let app = StorePageContentFixtures.app

    private func context() -> MCPToolContext {
        var workspace = MCPTestFixtures.workspace(apps: [app], storePage: FakeStorePageServices())
        workspace.suggestions = store
        return MCPToolContext(workspace: workspace, clientName: "Claude Code")
    }

    private func begin(_ locales: [JSONValue], fields: [JSONValue]? = nil, missingOnly: Bool? = nil) async throws -> JSONValue {
        var arguments: [String: JSONValue] = ["appId": "app1", "locales": .array(locales)]
        if let fields { arguments["fields"] = .array(fields) }
        if let missingOnly { arguments["missingOnly"] = .bool(missingOnly) }
        return try await BeginTranslationTool().call(MCPToolArguments(arguments), in: context()).result
    }

    private func end(_ run: String, locale: String? = nil) async throws -> JSONValue {
        var arguments: [String: JSONValue] = ["run": .string(run)]
        if let locale { arguments["locale"] = .string(locale) }
        return try await EndSuggestionsTool().call(MCPToolArguments(arguments), in: context()).result
    }

    @Test func withoutFieldsEachLanguageGetsWhatsEmptyThere() async throws {
        let result = try await begin(["de-DE"])
        #expect(result["maxAgents"] == JSONValue.int(NativeTranslationFlow.maxAgents))
        #expect(result["sourceLocale"] == "en-US")
        let german = try #require(result["languages"]?.arrayValue?.first)
        #expect(german["fields"] == ["privacyPolicyUrl", "promotionalText", "keywords", "whatsNew", "supportUrl", "marketingUrl"])
        #expect(result["accepted"] == 6)
        #expect(store.run?.kind == .translation)
        #expect(store.run?.languages == ["de-DE"])
        #expect(store.run?.progressText == "Translating · 0 of 1 language")
    }

    @Test func eachLanguageGetsANativeWriterAndAReviewer() async throws {
        let result = try await begin(["de-DE"], fields: ["subtitle", "keywords"])
        let german = try #require(result["languages"]?.arrayValue?.first)
        #expect(german["fields"] == ["subtitle", "keywords"])
        let run = try #require(result["run"]?.stringValue)
        let writer = try #require(german["writer"]?.stringValue)
        #expect(writer.contains("You are a native German speaker and an App Store copywriter"))
        #expect(writer.contains("get_translation_brief with appId app1, locale de-DE, fields [subtitle, keywords], run \(run)"))
        #expect(writer.contains("never word for word"))
        #expect(writer.contains("keywords 100 bytes"))
        #expect(writer.contains("Never touch another language."))
        #expect(writer.contains("Don't call end_suggestions"))
        let reviewer = try #require(german["reviewer"]?.stringValue)
        #expect(reviewer.contains("native German reader who didn't write these texts"))
        for field in NativeTranslationFlow.reviewFields {
            #expect(reviewer.contains(field), "\(field)")
        }
        #expect(reviewer.contains("end_suggestions with run \(run) and locale de-DE"))
    }

    @Test func missingOnlyKeepsTheEmptyOnes() async throws {
        let result = try await begin(["de-DE"], fields: ["subtitle", "keywords"], missingOnly: true)
        #expect(result["languages"]?.arrayValue?.first?["fields"] == ["keywords"])
    }

    @Test func theSourceAndLanguagesWithNothingToDoAreSaid() async throws {
        let result = try await begin(["en-US", "de-DE", "fr-FR"], fields: ["subtitle"])
        #expect(result["languages"]?.arrayValue?.map { $0["locale"] } == ["de-DE"])
        let nothing = try #require(result["nothingToDo"]?.arrayValue)
        #expect(nothing.map { $0["locale"] } == ["en-US", "fr-FR"])
        #expect(nothing[1]["skipped"]?.arrayValue?.first?["code"] == "unknown_locale")
    }

    @Test func captionsOnlyLanguagesEndThemselves() async throws {
        let result = try await begin(["de-DE"], fields: ["captions"])
        let german = try #require(result["languages"]?.arrayValue?.first)
        #expect(german["captions"] == true)
        #expect(german["reviewer"] == nil)
        #expect(german["writer"]?.stringValue?.contains("end_suggestions with run") == true)
        #expect(store.run?.phase == .running)
    }

    @Test func endingEachLanguageCountsItAndTheLastFinishes() async throws {
        let first = try await begin(["de-DE"], fields: ["subtitle"])
        let run = try #require(first["run"]?.stringValue)
        let ended = try await end(run, locale: "de-DE")
        #expect(ended["status"] == "finished")
        #expect(ended["languagesDone"] == 1)
        #expect(store.run?.phase == .finished)
        #expect(store.run?.title == "Finished translating")
    }

    @Test func aLanguageTheRunDoesntHaveIsNotFound() async throws {
        let run = try #require(try await begin(["de-DE"], fields: ["subtitle"])["run"]?.stringValue)
        await #expect(throws: MCPToolError.self) { try await end(run, locale: "ja") }
    }

    @Test func anotherRunGoingOnRefusesIt() async throws {
        store.startRun(appID: app.id, client: "Claude Code", plan: [.storePage(.englishUS, .subtitle)])
        await #expect(throws: MCPToolError.self) { try await begin(["de-DE"]) }
    }

    @Test func unknownCodesAreRefused() async {
        await #expect(throws: MCPToolError.self) { try await begin(["xx-YY"]) }
        await #expect(throws: MCPToolError.self) { try await begin([]) }
        await #expect(throws: MCPToolError.self) { try await begin(["de-DE"], fields: ["tagline"]) }
    }

    @Test func theToolsAreOffered() {
        let names = MCPToolbox.standard.toolNames
        #expect(names.contains("begin_translation"))
        #expect(names.contains("get_translation_brief"))
    }
}
