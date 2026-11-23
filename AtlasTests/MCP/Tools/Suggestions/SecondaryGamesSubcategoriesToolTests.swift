//
//  SecondaryGamesSubcategoriesToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `suggest_fields` and `get_app_information` on the secondary category's
/// Games subcategories (`secondaryGamesSubcategories`), on Lumen's sample
/// App Information: refused while the secondary category isn't Games,
/// suggested or applied once it is (here a queued change makes it Games).
@MainActor
@Suite("suggest_fields: secondary Games subcategories")
struct SecondaryGamesSubcategoriesToolTests {
    private let changes = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")

    private var builder: AppInformationChangeBuilder {
        let content = DebugAppInformationContent.lumen(versionID: nil)
        return AppInformationChangeBuilder(appID: lumen.id, ids: content.ids, versionString: content.version?.versionString)
    }

    private func context(editsDrafts: Bool = false) -> MCPToolContext {
        var workspace = MCPTestFixtures.workspace(
            apps: [lumen],
            changes: changes,
            storePage: FakeStorePageServices(),
            appInformation: DebugAppInformationServices()
        )
        workspace.suggestions = store
        var context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        context.editsDrafts = editsDrafts
        return context
    }

    private func suggest(_ value: String, apply: Bool = false) async throws -> JSONValue? {
        let item: JSONValue = ["page": "general", "field": "secondaryGamesSubcategories", "value": .string(value), "reason": "Word games."]
        var arguments: [String: JSONValue] = ["appId": .string(lumen.id), "items": [item]]
        if apply { arguments["apply"] = true }
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context(editsDrafts: apply))
        return outcome.result["results"]?.arrayValue?.first
    }

    private func entry() async throws -> JSONValue? {
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let pages = outcome.result["pages"]?.arrayValue ?? []
        return pages.first { $0["page"]?.stringValue == "general" }?["fields"]?["secondaryGamesSubcategories"]
    }

    /// Games as the secondary category, waiting in Review & Push.
    private func makeSecondaryGames() throws {
        try changes.upsert(#require(builder.categoryChange("secondaryCategory", from: "HEALTH_AND_FITNESS", to: "GAMES")))
    }

    @Test func refusedWhileTheSecondaryCategoryIsntGames() async throws {
        let result = try #require(await suggest("Word"))
        #expect(result["status"] == "refused")
        #expect(result["code"] == "invalid_value")
        #expect(result["reason"]?.stringValue?.contains("secondary category") == true)
        let field = try #require(await entry())
        #expect(field["available"] == false)
        #expect(field["max"] == 2)
        #expect(field["value"] == "")
    }

    @Test func suggestedOnceItIsGames() async throws {
        try makeSecondaryGames()
        #expect(try await entry()?["available"] == true)
        let result = try #require(await suggest("Word, Puzzle"))
        #expect(result["status"] == "queued")
        #expect(result["field"] == "secondaryGamesSubcategories")
        let suggestion = try #require(store.all(for: lumen.id).first { $0.target == .appInformation(.secondaryGamesSubcategories) })
        #expect(suggestion.value == "GAMES_WORD,GAMES_PUZZLE")
        // The primary category's pair is still refused: it isn't Games.
        let primary: JSONValue = ["page": "general", "field": "gamesSubcategories", "value": "Word"]
        let outcome = try await SuggestFieldsTool().call(
            MCPToolArguments(["appId": .string(lumen.id), "items": [primary]]), in: context()
        )
        #expect(outcome.result["results"]?.arrayValue?.first?["code"] == "invalid_value")
    }

    @Test func appliedAsTheSecondaryPairsChange() async throws {
        try makeSecondaryGames()
        let result = try #require(await suggest("GAMES_TRIVIA", apply: true))
        #expect(result["status"] == "applied")
        let id = builder.changeID(.general, AppInformationChangeBuilder.GeneralKey.secondaryGamesSubcategories)
        #expect(result["changeId"] == .string(id))
        let change = try #require(changes.change(id: id))
        #expect(AppInformationTestSupport.relationshipID(change.requests.first, "secondarySubcategoryOne") == "GAMES_TRIVIA")
        #expect(try await entry()?["value"] == "GAMES_TRIVIA")
    }

    @Test func theToolsNameTheField() {
        #expect(SuggestFieldsTool().definition.description.contains("secondaryGamesSubcategories"))
        #expect(GetAppInformationTool().definition.description.contains("secondaryGamesSubcategories"))
    }
}
#endif
