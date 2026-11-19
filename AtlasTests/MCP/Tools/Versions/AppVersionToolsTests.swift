//
//  AppVersionToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_app_versions` and `propose_app_version` on Lumen: only the live
/// 1.9, or 2.0 still in Prepare for Submission. A proposal is queued as the
/// assistant's "Create version 2.0", refused with App Store Connect's rule
/// otherwise, and never replaces the person's own.
@MainActor
@Suite("App version tools")
struct AppVersionToolsTests {
    private let changes = ChangeQueue()

    private func context(_ contents: [StorePageContent] = [StorePageContentFixtures.liveOnly]) -> MCPToolContext {
        let services = FakeStorePageServices(contents: contents)
        return MCPToolContext(workspace: MCPTestFixtures.workspace(changes: changes, storePage: services), clientName: "Claude Code")
    }

    private func propose(_ number: String, platform: String? = nil, in context: MCPToolContext? = nil) async throws -> JSONValue {
        var arguments: [String: JSONValue] = ["appId": "Lumen", "versionString": .string(number), "reason": .string("MARKETING_VERSION is \(number).")]
        if let platform { arguments["platform"] = .string(platform) }
        arguments["evidence"] = [.string("Lumen.xcodeproj — MARKETING_VERSION = \(number)")]
        let outcome = try await ProposeAppVersionTool().call(MCPToolArguments(arguments), in: context ?? self.context())
        #expect(!outcome.isError)
        return outcome.result
    }

    @Test func getAppVersionsSaysWhatCanBeCreated() async throws {
        let outcome = try await GetAppVersionsTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        let platforms = try #require(outcome.result["platforms"]?.arrayValue)
        #expect(platforms.count == 1)
        let iOS = try #require(platforms.first)
        #expect(iOS["platform"] == "IOS")
        #expect(iOS["latest"] == "1.9")
        #expect(iOS["suggestedNext"] == "1.10")
        #expect(iOS["canCreate"] == true)
        #expect(iOS["queued"] == .null)
        #expect(iOS["versions"]?.arrayValue?.first?["live"] == true)
    }

    /// Each version lists its builds as the Submit sheet reads them, and
    /// the one attached; a version whose builds can't be read says why.
    @Test func getAppVersionsShowsEachVersionsBuilds() async throws {
        let release = FakeReleaseServices()
        let uploaded = try #require(AppStoreConnectDate.date("2026-11-18T10:00:00Z"))
        release.versionBuilds["v2"] = ReleaseVersionBuilds(
            builds: [
                ReleaseBuild(id: "b212", number: "212", uploaded: uploaded, processing: .processing),
                ReleaseBuild(id: "b211", number: "211", uploaded: uploaded, processing: .valid, usesNonExemptEncryption: false),
            ],
            attachedBuildID: "b211", attachedBuildNumber: "211"
        )
        release.versionBuilds["v19"] = ReleaseVersionBuilds(attachedBuildID: "b190", attachedBuildNumber: "190")
        var workspace = MCPTestFixtures.workspace(
            changes: changes, storePage: FakeStorePageServices(contents: [StorePageContentFixtures.editable, StorePageContentFixtures.live])
        )
        workspace.services.release = release
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code")

        let outcome = try await GetAppVersionsTool().call(MCPToolArguments(["appId": "Lumen"]), in: context)
        let versions = try #require(outcome.result["platforms"]?.arrayValue?.first?["versions"]?.arrayValue)
        let next = try #require(versions.first { $0["versionString"] == "2.0" })
        let builds = try #require(next["builds"]?.arrayValue)
        #expect(builds.compactMap { $0["buildNumber"]?.stringValue } == ["212", "211"])
        #expect(builds[0]["processingState"] == "PROCESSING")
        #expect(builds[0]["attached"] == false)
        #expect(builds[0]["uploaded"] == "2026-11-18T10:00:00Z")
        #expect(builds[0]["usesNonExemptEncryption"] == nil)
        #expect(builds[1]["attached"] == true)
        #expect(builds[1]["usesNonExemptEncryption"] == false)
        #expect(next["attachedBuild"]?["id"] == "b211")
        #expect(next["attachedBuild"]?["processingState"] == "VALID")
        // The live version's build is older than those listed: its number
        // comes with the attachment.
        let live = try #require(versions.first { $0["versionString"] == "1.9" })
        #expect(live["builds"]?.arrayValue?.isEmpty == true)
        #expect(live["attachedBuild"]?["buildNumber"] == "190")

        release.failingBuilds = ["v2"]
        let failed = try await GetAppVersionsTool().call(MCPToolArguments(["appId": "Lumen"]), in: context)
        let unread = try #require(failed.result["platforms"]?.arrayValue?.first?["versions"]?.arrayValue?.first { $0["versionString"] == "2.0" })
        #expect(unread["builds"] == nil)
        #expect(unread["buildsError"]?.stringValue?.isEmpty == false)
        #expect(!failed.isError)
    }

    @Test func aVersionInProgressCantBeCreated() async throws {
        let inProgress = context([StorePageContentFixtures.editable, StorePageContentFixtures.live])
        let outcome = try await GetAppVersionsTool().call(MCPToolArguments(["appId": "Lumen"]), in: inProgress)
        let iOS = try #require(outcome.result["platforms"]?.arrayValue?.first)
        #expect(iOS["canCreate"] == false)
        #expect(iOS["whyNot"]?.stringValue?.contains("2.0") == true)

        let result = try await propose("2.1", in: inProgress)
        #expect(result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func aProposalIsQueuedAsTheAssistants() async throws {
        let result = try await propose("2.0")
        #expect(result["status"] == "queued")
        #expect(result["changeId"] == "appStoreVersion.6450000001.IOS")
        let change = try #require(changes.change(id: "appStoreVersion.6450000001.IOS"))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.creation?.detail.contains("MARKETING_VERSION is 2.0.") == true)
        #expect(NewAppVersionChangeBuilder.version(of: change) == NewAppVersion(versionString: "2.0", platform: "IOS"))

        let again = try await propose("2.0")
        #expect(again["status"] == "unchanged")
        let higher = try await propose("2.1")
        #expect(higher["status"] == "queued")
        #expect(changes.changes.count == 1)
        #expect(changes.changes.first?.title == "Version 2.1")
    }

    @Test func whatAppStoreConnectWouldRefuseIsRefused() async throws {
        #expect(try await propose("1.9")["status"] == "refused")
        #expect(try await propose("2.0-beta")["status"] == "refused")
        let mac = try await propose("2.0", platform: "macOS")
        #expect(mac["reason"]?.stringValue == "The app has no macOS version. Add the platform in App Store Connect first.")
        await #expect(throws: MCPToolError.self) { try await propose("2.0", platform: "Android") }
        #expect(changes.changes.isEmpty)
    }

    @Test func thePersonsOwnVersionIsntReplaced() async throws {
        let mine = NewAppVersionChangeBuilder(appID: "6450000001").change(for: NewAppVersion(versionString: "2.0", platform: "IOS"), showsPlatform: false)
        changes.upsert(mine)
        let result = try await propose("3.0")
        #expect(result["status"] == "refused")
        #expect(changes.change(id: mine.id)?.source == .you)
        #expect(changes.change(id: mine.id)?.title == "Version 2.0")
    }

    @Test func platformNamesAreForgiving() {
        #expect(MCPAppVersions.platform(named: "ios") == "IOS")
        #expect(MCPAppVersions.platform(named: "macOS") == "MAC_OS")
        #expect(MCPAppVersions.platform(named: "MAC_OS") == "MAC_OS")
        #expect(MCPAppVersions.platform(named: "visionOS") == "VISION_OS")
        #expect(MCPAppVersions.platform(named: "watchOS") == nil)
    }
}
#endif
