//
//  QueuedVersionTextsToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A new version queued with `propose_app_version` counts as the version
/// being prepared: Lumen Journal's 2.0 (only 1.9 is live) and Lumen's 1.5
/// (App Information) are read from the version before them and editable,
/// and texts written for them wait tied to them in Review & Push. A version
/// that's neither in App Store Connect nor queued is refused with what to do.
@MainActor
@Suite("Texts for a queued version")
struct QueuedVersionTextsToolsTests {
    private let changes = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let storeApp = StorePageContentFixtures.app
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")

    private var versionChangeID: String { "appStoreVersion.app1.IOS" }

    private func context(_ contents: [StorePageContent] = [StorePageContentFixtures.liveOnly]) -> MCPToolContext {
        var workspace = MCPTestFixtures.workspace(
            apps: [storeApp, lumen],
            changes: changes,
            storePage: FakeStorePageServices(contents: contents),
            appInformation: DebugAppInformationServices()
        )
        workspace.suggestions = store
        return MCPToolContext(workspace: workspace, clientName: "Claude Code")
    }

    private func queue(_ number: String, for appID: StoreApp.ID = "app1") {
        let builder = NewAppVersionChangeBuilder(appID: appID)
        changes.upsert(builder.change(
            for: NewAppVersion(versionString: number, platform: "IOS"),
            showsPlatform: false,
            source: .assistant(client: "Claude Code")
        ))
    }

    private func message(of error: any Error) -> String {
        guard case let MCPToolError.notFound(message) = error else { return "\(error)" }
        return message
    }

    // MARK: - Reading

    @Test func aQueuedVersionIsReadAsTheOneBeingPrepared() async throws {
        queue("2.0")
        let outcome = try await GetListingTool().call(MCPToolArguments(["appId": "app1", "version": "2.0"]), in: context())
        let version = try #require(outcome.result["version"])
        #expect(version["versionString"] == "2.0")
        #expect(version["queued"] == true)
        #expect(version["editable"] == true)
        #expect(outcome.result["fields"]?["whatsNew"]?["editable"] == true)
        #expect(outcome.result["fields"]?["description"]?["editable"] == true)

        // Without `version`, it's still the live 1.9, read-only.
        let live = try await GetListingTool().call(MCPToolArguments(["appId": "app1"]), in: context())
        #expect(live.result["version"]?["versionString"] == "1.9")
        #expect(live.result["fields"]?["whatsNew"]?["editable"] == false)
    }

    @Test func itsAppReviewDetailsStartFromTheVersionBefore() async throws {
        queue("1.5", for: lumen.id)
        let now = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id), "version": "1.5"]), in: context())
        #expect(outcome.result["version"]?["versionString"] == "1.5")
        #expect(outcome.result["version"]?["queued"] == true)
        let notes = try #require(Self.field("notes", on: "review", in: outcome.result))
        #expect(notes["locked"] == false)
        #expect(notes["value"] == Self.field("notes", on: "review", in: now.result)?["value"])
    }

    // MARK: - Writing

    @Test func aProposedTextWaitsTiedToTheVersion() async throws {
        queue("2.0")
        let arguments: [String: JSONValue] = [
            "appId": "app1", "version": "2.0", "locale": "en-US", "field": "whatsNew", "text": "Weekly reviews, now in widgets.",
        ]
        let outcome = try await ProposeListingTextTool().call(MCPToolArguments(arguments), in: context())
        #expect(outcome.result["status"] == "queued")
        let id = try #require(outcome.result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.dependsOn == versionChangeID)
        #expect(change.section == .storePage)
        #expect(change.group == changes.change(id: versionChangeID)?.group)
        #expect(change.creation?.id == versionChangeID)
        #expect(change.conflictCheck == nil)
        #expect(change.requests.first?.path == "/v1/appStoreVersionLocalizations/{queuedVersion:IOS:2.0:localization:en-US}")
        #expect(change.newValue == "Weekly reviews, now in widgets.")

        // Its row in Review & Push: the version, with the text below it.
        let creation = try #require(ReviewCreation.group(changes.changes).first)
        #expect(creation.title == "Create version 2.0")
        #expect(creation.changeIDs == [versionChangeID, id])
        #expect(creation.fields.map(\.newValue) == ["Weekly reviews, now in widgets."])
    }

    /// Name and subtitle can't change in the live app info: App Store
    /// Connect makes a new one with the version, and they wait for it.
    @Test func itsSubtitleGoesIntoTheAppInfoMadeWithIt() async throws {
        queue("2.0")
        let arguments: [String: JSONValue] = [
            "appId": "app1", "version": "2.0", "locale": "en-US", "field": "subtitle", "text": "Reflect every week",
        ]
        let outcome = try await ProposeListingTextTool().call(MCPToolArguments(arguments), in: context())
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first { $0.id != versionChangeID })
        #expect(change.dependsOn == versionChangeID)
        #expect(change.creation?.id == versionChangeID)
        #expect(change.requests.first?.path == "/v1/appInfoLocalizations/{queuedVersion:IOS:2.0:appInfoLocalization:en-US}")
    }

    @Test func itsCategoryWaitsWithItToo() async throws {
        queue("1.5", for: lumen.id)
        let arguments: [String: JSONValue] = [
            "appId": .string(lumen.id), "version": "1.5",
            "items": [["area": "info", "page": "general", "field": "secondaryCategory", "value": "Productivity"]],
        ]
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context())
        let result = try #require(outcome.result["results"]?.arrayValue?.first)
        #expect(result["status"] == "applied")
        #expect(store.suggestions.isEmpty)
        let id = try #require(result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.dependsOn == "appStoreVersion.\(lumen.id).IOS")
        #expect(change.requests.first?.path == "/v1/appInfos/{queuedVersion:IOS:1.5:appInfo}")
        #expect(change.conflictCheck == nil)
    }

    @Test func theRulesStillApply() async throws {
        queue("2.0")
        let arguments: [String: JSONValue] = [
            "appId": "app1", "version": "2.0", "locale": "en-US", "field": "whatsNew", "text": "Now free for everyone!",
        ]
        let outcome = try await ProposeListingTextTool().call(MCPToolArguments(arguments), in: context())
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.count == 1)
    }

    @Test func suggestionsForItAreQueuedWithIt() async throws {
        queue("1.5", for: lumen.id)
        let arguments: [String: JSONValue] = [
            "appId": .string(lumen.id),
            "version": "1.5",
            "items": [
                ["area": "info", "page": "review", "field": "notes", "value": "Sign in with the demo account; reminders are under Settings."],
            ],
        ]
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context())
        let result = try #require(outcome.result["results"]?.arrayValue?.first)
        #expect(result["status"] == "applied")
        #expect(result["note"]?.stringValue?.contains("Version 1.5 is queued in Review & Push") == true)
        #expect(store.suggestions.isEmpty)
        let id = try #require(result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.dependsOn == "appStoreVersion.\(lumen.id).IOS")
        #expect(change.requests.first?.path == "/v1/appStoreReviewDetails/{queuedVersion:IOS:1.5:reviewDetail}")

        // Read back with the version, the notes are the ones queued.
        let read = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id), "version": "1.5"]), in: context())
        #expect(Self.field("notes", on: "review", in: read.result)?["value"] == "Sign in with the demo account; reminders are under Settings.")
    }

    @Test func storeTextSuggestionsForItAreQueuedToo() async throws {
        queue("2.0")
        let arguments: [String: JSONValue] = [
            "appId": "app1",
            "version": "2.0",
            "items": [["area": "store", "locale": "de-DE", "field": "whatsNew", "value": "Wöchentliche Rückblicke."]],
        ]
        let outcome = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context())
        #expect(outcome.result["results"]?.arrayValue?.first?["status"] == "applied")
        let text = try #require(changes.changes.first { $0.dependsOn == versionChangeID })
        #expect(text.requests.first?.path == "/v1/appStoreVersionLocalizations/{queuedVersion:IOS:2.0:localization:de-DE}")
        #expect(store.suggestions.isEmpty)
    }

    @Test func discardingTheVersionDiscardsItsTexts() async throws {
        queue("2.0")
        let arguments: [String: JSONValue] = [
            "appId": "app1", "version": "2.0", "locale": "en-US", "field": "whatsNew", "text": "Weekly reviews.",
        ]
        _ = try await ProposeListingTextTool().call(MCPToolArguments(arguments), in: context())
        #expect(changes.changes.count == 2)
        changes.discard(id: versionChangeID)
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Refusals

    @Test func aVersionThatIsntQueuedSaysToProposeIt() async throws {
        do {
            _ = try await GetListingTool().call(MCPToolArguments(["appId": "app1", "version": "2.0"]), in: context())
            Issue.record("Expected a refusal")
        } catch {
            #expect(message(of: error) == "2.0 isn’t in App Store Connect or queued in Atlas for Lumen Journal; "
                + "propose it with propose_app_version first, then its texts for it.")
        }
        let item: JSONValue = ["area": "store", "locale": "en-US", "field": "whatsNew", "value": "New"]
        let arguments: [String: JSONValue] = ["appId": "app1", "version": "2.0", "items": [item]]
        await #expect(throws: MCPToolError.self) { try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context()) }
        #expect(changes.changes.isEmpty)
    }

    @Test func anOlderVersionIsReadOnlyAndSaysWhichOneIsBeingPrepared() async throws {
        let editable = [StorePageContentFixtures.editable, StorePageContentFixtures.live]
        // Reading an older version is allowed (read-only, to see what a past release said).
        let older = try await GetListingTool().call(MCPToolArguments(["appId": "app1", "version": "1.9"]), in: context(editable))
        #expect(older.result["version"]?["versionString"] == "1.9")
        // Writing to it is refused with the version being prepared.
        let item: JSONValue = ["area": "store", "locale": "en-US", "field": "whatsNew", "value": "New"]
        let arguments: [String: JSONValue] = ["appId": "app1", "version": "1.9", "items": [item]]
        do {
            _ = try await SuggestFieldsTool().call(MCPToolArguments(arguments), in: context(editable))
            Issue.record("Expected a refusal")
        } catch {
            #expect(message(of: error).contains("version being prepared is 2.0, not 1.9"))
        }
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Helpers

    /// A field of get_app_information's result.
    private static func field(_ name: String, on page: String, in result: JSONValue) -> JSONValue? {
        let pages = result["pages"]?.arrayValue ?? []
        return pages.first { $0["page"]?.stringValue == page }?["fields"]?[name]
    }
}
#endif
