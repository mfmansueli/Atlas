//
//  ListingAddLanguagesToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_listing_text`'s addLanguages: a new language comes with its
/// texts, and its page waits for the person's Accept in Review & Push.
@MainActor
@Suite("propose_listing_text: adding languages")
struct ListingAddLanguagesToolTests {
    private let changes = ChangeQueue()

    private func call(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: [StorePageContentFixtures.app], changes: changes, storePage: FakeStorePageServices())
        var arguments = arguments
        arguments["appId"] = "app1"
        return try await ProposeListingTextTool().call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func anAddedLanguageWaitsForThePersonsAccept() async throws {
        let outcome = try await call([
            "addLanguages": ["fr-FR"], "locale": "fr-FR", "field": "promotionalText", "text": "Des bilans chaque semaine.",
        ])
        #expect(outcome.result["addedLanguages"]?.arrayValue?.contains("fr-FR") == true)
        #expect(changes.changes.contains { $0.awaitingAcceptance?.contains("French") == true })
        #expect(changes.changes.contains { $0.newValue == "Des bilans chaque semaine." })
    }

    @Test func aLanguageTheListingHasIsntAddedAgain() async throws {
        let outcome = try await call(["addLanguages": ["de-DE"], "locale": "de-DE", "field": "promotionalText", "text": "Wöchentliche Rückblicke."])
        #expect(outcome.result["addedLanguages"] == nil || outcome.result["addedLanguages"]?.arrayValue?.isEmpty == true)
        #expect(!changes.changes.contains { $0.awaitingAcceptance != nil })
    }

    @Test func anUnknownLocaleThrows() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(["addLanguages": ["xx-XX"], "locale": "de-DE", "field": "promotionalText", "text": "Text."])
        }
    }

    @Test func theSchemaTakesPlatformAndAddLanguages() {
        let properties = ProposeListingTextTool().definition.inputSchema["properties"]
        #expect(properties?["platform"] != nil)
        #expect(properties?["addLanguages"] != nil)
    }
}
