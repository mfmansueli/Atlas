//
//  GetListingFieldsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_listing`'s `fields`: only the fields asked for, in every locale or
/// in `locales`; "urls" for the three URLs. Without it, the whole listing,
/// as before.
@MainActor
@Suite("get_listing · fields")
struct GetListingFieldsTests {
    private let services = FakeStorePageServices()

    private func call(_ arguments: [String: JSONValue]) async throws -> JSONValue {
        let workspace = MCPTestFixtures.workspace(apps: [StorePageContentFixtures.app], storePage: services)
        return try await GetListingTool().call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: "Claude Code")).result
    }

    private static func keys(_ value: JSONValue?) -> Set<String> {
        Set(value?.objectValue?.keys.map(\.self) ?? [])
    }

    @Test func withoutFieldsEveryFieldComes() async throws {
        let result = try await call(["appId": "app1"])
        let fields = Self.keys(result["fields"])
        #expect(fields.contains("description"))
        #expect(fields.contains("whatsNew"))
        #expect(fields.contains("supportUrl"))
        #expect(result["fieldsNotInThisVersion"] == nil)
    }

    @Test func onlyTheFieldsAskedForComeInEachLocale() async throws {
        let result = try await call(["appId": "app1", "fields": ["subtitle", "whatsNew"]])
        #expect(Self.keys(result["fields"]) == ["subtitle", "whatsNew"])
        let locales = try #require(result["locales"]?.arrayValue)
        #expect(locales.count == 2)
        for locale in locales {
            #expect(Self.keys(locale["texts"]).isSubset(of: ["subtitle", "whatsNew"]))
            #expect(Self.keys(locale["states"]).isSubset(of: ["subtitle", "whatsNew"]))
        }
        #expect(locales[0]["texts"]?["subtitle"] == "Private notes, gentle prompts")
        #expect(locales[0]["texts"]?["description"] == nil)
        // The rules for writing store text still come.
        #expect(result["storeTextRules"] == StoreTextRules.json)
    }

    @Test func urlsStandsForTheThreeURLs() async throws {
        let result = try await call(["appId": "app1", "fields": ["urls"]])
        #expect(Self.keys(result["fields"]) == ["privacyPolicyUrl", "supportUrl", "marketingUrl"])
    }

    @Test func fieldsAndLocalesTogether() async throws {
        let result = try await call(["appId": "app1", "fields": ["promotionalText"], "locales": ["de-DE"]])
        let locales = try #require(result["locales"]?.arrayValue)
        #expect(locales.map { $0["code"] } == ["de-DE"])
        #expect(locales[0]["states"]?["promotionalText"] == "missing")
        #expect(Self.keys(locales[0]["states"]) == ["promotionalText"])
    }

    @Test func namesIgnoreCaseAndUnderscores() async throws {
        let result = try await call(["appId": "app1", "fields": ["WHATS_NEW", "Keywords"]])
        #expect(Self.keys(result["fields"]) == ["whatsNew", "keywords"])
    }

    @Test func anUnknownFieldIsAnErrorNamingTheKnownOnes() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(["appId": "app1", "fields": ["screenshots"]])
        }
        let definition = GetListingTool().definition
        #expect(definition.inputSchema["properties"]?["fields"]?["items"]?["enum"]?.arrayValue?.contains("urls") == true)
        #expect(definition.description.contains("fields: [\"whatsNew\"]"))
    }
}
