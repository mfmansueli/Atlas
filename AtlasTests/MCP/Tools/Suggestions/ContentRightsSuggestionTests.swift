//
//  ContentRightsSuggestionTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Content rights ("Does your app contain, show, or access third-party
/// content?") as a General field over MCP: `get_app_information` reads it
/// with Apple's question and the two ids, `suggest_fields` takes an id or
/// Yes/No and refuses anything else, and an accepted or applied Yes waits
/// for the person's "I have the rights to use it". Lumen's sample says No.
@MainActor
@Suite("Content rights over MCP")
struct ContentRightsSuggestionTests {
    private let changes = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")

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

    private func suggest(_ items: [JSONValue], apply: Bool = false, version: String? = nil) async throws -> [JSONValue] {
        var arguments: [String: JSONValue] = ["appId": .string(lumen.id), "items": .array(items)]
        if apply { arguments["apply"] = true }
        if let version { arguments["version"] = .string(version) }
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context(editsDrafts: apply))
        return outcome.result["results"]?.arrayValue ?? []
    }

    private func item(_ value: String, page: String = "general") -> JSONValue {
        ["area": "info", "page": .string(page), "field": "contentRights", "value": .string(value), "reason": "Bundles a licensed font."]
    }

    private func read(version: String? = nil) async throws -> JSONValue {
        var arguments: [String: JSONValue] = ["appId": .string(lumen.id)]
        if let version { arguments["version"] = .string(version) }
        return try await GetAppInformationTool().call(MCPToolArguments(arguments), in: context()).result
    }

    private static func contentRights(in result: JSONValue) -> JSONValue? {
        result["pages"]?.arrayValue?.first { $0["page"] == "general" }?["fields"]?["contentRights"]
    }

    private var suggested: String? {
        store.all(for: lumen.id).first { $0.target == .appInformation(.contentRights) }?.value
    }

    // MARK: - Reading

    @Test func itsReadWithApplesQuestionAndBothChoices() async throws {
        let result = try await read()
        let entry = try #require(Self.contentRights(in: result))
        #expect(entry["value"] == "DOES_NOT_USE_THIRD_PARTY_CONTENT")
        #expect(entry["name"] == "No")
        #expect(entry["locked"] == false)
        #expect(entry["live"] == nil)
        #expect(entry["rightsConfirmed"] == nil)
        #expect(entry["question"] == "Does your app contain, show, or access third-party content?")
        let choices = try #require(result["choices"]?["contentRights"]?.arrayValue)
        #expect(choices.map { $0["id"] } == ["USES_THIRD_PARTY_CONTENT", "DOES_NOT_USE_THIRD_PARTY_CONTENT"])
        #expect(choices.map { $0["name"] } == ["Yes", "No"])
        #expect(choices[0]["answer"]?.stringValue?.hasSuffix("and I have the necessary rights") == true)
    }

    @Test func aQueuedYesReadsWithTheLiveNoAndUnconfirmedRights() async throws {
        _ = try await suggest([item("yes")], apply: true)
        let result = try await read()
        let entry = try #require(Self.contentRights(in: result))
        #expect(entry["value"] == "USES_THIRD_PARTY_CONTENT")
        #expect(entry["name"] == "Yes")
        #expect(entry["live"] == "DOES_NOT_USE_THIRD_PARTY_CONTENT")
        #expect(entry["rightsConfirmed"] == false)
    }

    @Test func bothToolsDescribeTheField() {
        #expect(GetAppInformationTool().definition.description.contains("contentRights"))
        #expect(GetAppInformationTool().definition.description.contains("USES_THIRD_PARTY_CONTENT"))
        #expect(SuggestFieldsTool().definition.description.contains("contentRights"))
        let prompt = MCPPrompt.suggestAll.message(app: "Lumen", area: nil)["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(prompt.contains("contentRights"))
    }

    // MARK: - Suggesting

    @Test func yesAndIDsAreStoredAsTheID() async throws {
        let yes = try await suggest([item("Yes")])
        #expect(yes.first?["status"] == "queued")
        #expect(yes.first?["page"] == "general")
        #expect(suggested == "USES_THIRD_PARTY_CONTENT")
        #expect(changes.changes.isEmpty)

        let byID = try await suggest([item("uses_third_party_content")])
        #expect(byID.first?["status"] == "unchanged")
    }

    @Test func noIsUnchangedWhileAppStoreConnectSaysNo() async throws {
        let results = try await suggest([item("no"), item("DOES_NOT_USE_THIRD_PARTY_CONTENT"), item("false")])
        #expect(results.map { $0["status"] } == ["unchanged", "unchanged", "unchanged"])
        #expect(store.suggestions.isEmpty)
    }

    @Test func anythingElseIsAnInvalidValue() async throws {
        let results = try await suggest([item("Maybe"), item(""), item("THIRD_PARTY")])
        #expect(results.map { $0["status"] } == ["refused", "refused", "refused"])
        #expect(results.map { $0["code"] } == ["invalid_value", "invalid_value", "invalid_value"])
        #expect(store.suggestions.isEmpty)
    }

    @Test func itsAGeneralField() async throws {
        let results = try await suggest([item("yes", page: "review")])
        #expect(results.first?["code"] == "unknown_field")
    }

    @Test func anAppliedYesWaitsForTheRights() async throws {
        let results = try await suggest([item("yes")], apply: true)
        let result = try #require(results.first)
        #expect(result["status"] == "applied")
        #expect(result["note"]?.stringValue?.contains("confirms in Atlas that they have the rights") == true)
        let id = try #require(result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.blockedReason != nil)
        #expect(change.requests.first?.path == "/v1/apps/\(lumen.id)")
        #expect(store.suggestions.isEmpty)
    }

    /// A queued version doesn't take it: it's the app's, so it's a
    /// suggestion on General as without `version`.
    @Test func aQueuedVersionLeavesItToTheApp() async throws {
        let builder = NewAppVersionChangeBuilder(appID: lumen.id)
        changes.upsert(builder.change(
            for: NewAppVersion(versionString: "1.5", platform: "IOS"),
            showsPlatform: false,
            source: .assistant(client: "Claude Code")
        ))
        let results = try await suggest([item("yes")], version: "1.5")
        #expect(results.first?["status"] == "queued")
        #expect(suggested == "USES_THIRD_PARTY_CONTENT")
        #expect(changes.changes.count == 1)
        let queuedRead = try await read(version: "1.5")
        #expect(Self.contentRights(in: queuedRead)?["locked"] == false)
    }
}
#endif
