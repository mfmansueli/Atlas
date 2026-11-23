//
//  AppInformationMoreFieldsToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `suggest_fields` and `get_app_information` on the fields beyond
/// contact and notes: App Review's sign-in and demo user name (never the
/// password), Games subcategories (only for a game), the app's
/// accessibility URL and App Privacy's User Privacy Choices URL per
/// language, on Lumen's sample App Information, and for a new version
/// queued in Review & Push.
@MainActor
@Suite("suggest_fields: sign-in, subcategories and URLs")
struct AppInformationMoreFieldsToolTests {
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

    private func suggestion(_ target: SuggestionTarget) -> FieldSuggestion? {
        store.all(for: lumen.id).first { $0.target == target }
    }

    private func queueVersion(_ number: String) {
        changes.upsert(NewAppVersionChangeBuilder(appID: lumen.id).change(
            for: NewAppVersion(versionString: number, platform: "IOS"),
            showsPlatform: false,
            source: .assistant(client: "Claude Code")
        ))
    }

    private var builder: AppInformationChangeBuilder {
        let content = DebugAppInformationContent.lumen(versionID: nil)
        return AppInformationChangeBuilder(appID: lumen.id, ids: content.ids, versionString: content.version?.versionString)
    }

    // MARK: - App Review

    @Test func signInAndTheDemoUserNameAreSuggestedButNeverThePassword() async throws {
        let items = try await suggest([
            ["page": "review", "field": "demoAccountRequired", "value": "Yes", "reason": "The app opens on a sign-in screen."],
            ["page": "review", "field": "userName", "value": "review@lumen.example"],
            ["page": "review", "field": "demoAccountPassword", "value": "hunter2"],
            ["page": "review", "field": "password", "value": "hunter2"],
            ["page": "review", "field": "demoAccountRequired", "value": "maybe"],
        ])
        #expect(items.map { $0["status"] } == ["queued", "queued", "refused", "refused", "refused"])
        #expect(items.map { $0["code"] } == [nil, nil, "unknown_field", "unknown_field", "invalid_value"])
        #expect(items[1]["field"] == "demoAccountName")
        #expect(suggestion(.appInformation(.demoAccountRequired))?.value == "yes")
        #expect(suggestion(.appInformation(.demoAccountName))?.value == "review@lumen.example")
        #expect(!store.all(for: lumen.id).contains { $0.value == "hunter2" })
    }

    @Test func appliedSignInQueuesTheReviewDetailAndSaysWhoTypesThePassword() async throws {
        let items = try await suggest([["page": "review", "field": "signInRequired", "value": "true"]], apply: true)
        let result = try #require(items.first)
        #expect(result["status"] == "applied")
        #expect(result["note"] == .string(MCPSuggestionSession.passwordNote))
        let change = try #require(changes.change(id: builder.reviewChangeID(.signInRequired)))
        let bodies = change.requests.compactMap { $0.body.flatMap { String(data: $0, encoding: .utf8) } }
        #expect(bodies.contains { $0.contains("demoAccountRequired") })
        #expect(!bodies.contains { $0.contains("demoAccountPassword") })
    }

    @Test func getAppInformationListsSignInWithoutAPassword() async throws {
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let review = try #require(Self.fields(on: "review", in: outcome.result))
        #expect(review["demoAccountRequired"]?["value"] == "no")
        #expect(review["demoAccountName"]?["value"] == "")
        #expect(review["demoAccountPassword"] == nil)
        #expect(review["password"] == nil)
        let description = GetAppInformationTool().definition.description
        #expect(description.contains("password is never read or suggested"))
    }

    // MARK: - Games subcategories

    @Test func subcategoriesAreRefusedForAnAppThatIsntAGame() async throws {
        let items = try await suggest([["page": "general", "field": "gamesSubcategories", "value": "Puzzle"]])
        #expect(items.first?["code"] == "invalid_value")
        #expect(items.first?["reason"]?.stringValue?.contains("Games") == true)
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let entry = try #require(Self.fields(on: "general", in: outcome.result)?["gamesSubcategories"])
        #expect(entry["available"] == false)
        #expect(entry["max"] == 2)
        #expect(outcome.result["choices"]?["gamesSubcategories"]?.arrayValue?.count == AppCategory.gamesSubcategories.count)
    }

    // MARK: - Accessibility URL

    @Test func theAccessibilityURLIsTheAppsWithoutADevice() async throws {
        let items = try await suggest([
            ["page": "accessibility", "field": "accessibilityUrl", "value": "https://lumen.example/a11y", "reason": "The site has the page."],
            ["page": "accessibility", "field": "accessibilityUrl", "value": "lumen.example/a11y"],
        ])
        #expect(items.map { $0["status"] } == ["queued", "refused"])
        #expect(items[1]["code"] == "invalid_value")
        #expect(items[0]["page"] == "accessibility")
        #expect(items[0]["device"] == nil)
        #expect(suggestion(.appInformation(.accessibilityURL))?.value == "https://lumen.example/a11y")
    }

    @Test func applyingTheAccessibilityURLQueuesTheAppsChange() async throws {
        let items = try await suggest([["field": "accessibilityUrl", "value": "https://lumen.example/a11y"]], apply: true)
        #expect(items.first?["status"] == "applied")
        let id = builder.changeID(.accessibility, AppInformationChangeBuilder.accessibilityURLKey)
        #expect(items.first?["changeId"] == .string(id))
        #expect(changes.change(id: id)?.requests.first?.path == "/v1/apps/\(lumen.id)")
    }

    @Test func getAppInformationReadsTheAccessibilityURL() async throws {
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let page = try #require(outcome.result["pages"]?.arrayValue?.first { $0["page"] == "accessibility" })
        #expect(page["url"]?["value"]?.stringValue != nil)
        #expect(page["url"]?["locked"] == false)
    }

    // MARK: - User Privacy Choices URL

    @Test func thePrivacyChoicesURLIsSuggestedPerLanguage() async throws {
        let items = try await suggest([
            ["page": "appPrivacy", "locale": "de-DE", "field": "privacyChoicesUrl", "value": "https://lumen.example/de/choices", "reason": "German page."],
            ["locale": "fr-FR", "field": "privacyChoicesUrl", "value": "https://lumen.example/fr/choices"],
            ["page": "appPrivacy", "field": "privacyChoicesUrl", "value": "https://lumen.example/choices"],
            ["page": "appPrivacy", "locale": "xx-XX", "field": "privacyChoicesUrl", "value": "https://lumen.example/choices"],
            ["page": "appPrivacy", "locale": "de-DE", "field": "privacyPolicyUrl", "value": "https://lumen.example/privacy"],
            ["page": "privacy", "locale": "de-DE", "field": "privacyChoicesUrl", "value": "not a url"],
        ])
        #expect(items.map { $0["status"] } == ["queued", "queued", "refused", "refused", "refused", "refused"])
        #expect(items.map { $0["code"] } == [nil, nil, "unknown_locale", "unknown_locale", "unknown_field", "invalid_value"])
        #expect(items[0]["locale"] == "de-DE")
        #expect(items[0]["page"] == "appPrivacy")
        let german = try #require(suggestion(AppInformationSuggestionSlot.privacyChoicesURL(.german).target))
        #expect(german.value == "https://lumen.example/de/choices")
        #expect(german.target.scope == .appPrivacy(locale: "de-DE"))
        #expect(german.mcpJSON["locale"] == "de-DE")
    }

    @Test func applyingThePrivacyChoicesURLQueuesItsLocalization() async throws {
        let items = try await suggest(
            [["page": "appPrivacy", "locale": "de-DE", "field": "privacyChoicesUrl", "value": "https://lumen.example/de/choices"]],
            apply: true
        )
        #expect(items.first?["status"] == "applied")
        let id = try #require(items.first?["changeId"]?.stringValue)
        #expect(id == builder.privacyChoicesChangeID(.german))
        let change = try #require(changes.change(id: id))
        #expect(change.requests.first?.path == "/v1/appInfoLocalizations/\(DebugStorePageContent.appInfoID)-de-DE")
    }

    @Test func getAppInformationListsEveryLanguagesPrivacyChoicesURL() async throws {
        let outcome = try await GetAppInformationTool().call(MCPToolArguments(["appId": .string(lumen.id)]), in: context())
        let page = try #require(outcome.result["pages"]?.arrayValue?.first { $0["page"] == "appPrivacy" })
        #expect(page["available"] == true)
        let locales = page["locales"]?.arrayValue ?? []
        #expect(locales.count == DebugAppInformationContent.privacyURLs(for: lumen).locales.count)
        let german = try #require(locales.first { $0["locale"] == "de-DE" })
        #expect(german["fields"]?["privacyChoicesUrl"]?["value"]?.stringValue != nil)
    }

    // MARK: - A queued version

    @Test func aQueuedVersionsPrivacyChoicesURLWaitsWithIt() async throws {
        queueVersion("1.5")
        let items = try await suggest(
            [["page": "appPrivacy", "locale": "de-DE", "field": "privacyChoicesUrl", "value": "https://lumen.example/de/choices"]],
            version: "1.5"
        )
        let result = try #require(items.first)
        #expect(result["status"] == "applied")
        #expect(store.suggestions.isEmpty)
        let change = try #require(changes.change(id: result["changeId"]?.stringValue ?? ""))
        #expect(change.dependsOn == "appStoreVersion.\(lumen.id).IOS")
        #expect(change.requests.first?.path == "/v1/appInfoLocalizations/{queuedVersion:IOS:1.5:appInfoLocalization:de-DE}")
        #expect(change.conflictCheck == nil)
    }

    @Test func aQueuedVersionsSignInWaitsWithItAndTheAccessibilityURLStaysTheApps() async throws {
        queueVersion("1.5")
        let items = try await suggest([
            ["page": "review", "field": "demoAccountRequired", "value": "yes"],
            ["page": "accessibility", "field": "accessibilityUrl", "value": "https://lumen.example/a11y"],
        ], version: "1.5")
        #expect(items.map { $0["status"] } == ["applied", "queued"])
        let review = try #require(changes.change(id: items[0]["changeId"]?.stringValue ?? ""))
        #expect(review.dependsOn == "appStoreVersion.\(lumen.id).IOS")
        #expect(suggestion(.appInformation(.accessibilityURL)) != nil)
    }

    private static func fields(on page: String, in result: JSONValue) -> JSONValue? {
        let pages = result["pages"]?.arrayValue ?? []
        return pages.first { $0["page"]?.stringValue == page }?["fields"]
    }
}
#endif
