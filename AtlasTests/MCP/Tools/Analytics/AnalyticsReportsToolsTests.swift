//
//  AnalyticsReportsToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_analytics_retention`, `get_analytics_subscribers`,
/// `get_analytics_crashes`, `get_analytics_after_download` and
/// `get_analytics_web_preview` against the sample account's reports.
@MainActor
@Suite("Analytics MCP tools · Apple's newer reports")
struct AnalyticsReportsToolsTests {
    private let store = DebugAnalyticsData.store()

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        // The sample account's Parcel Pal and Quiet Timer too: the reports
        // below are theirs.
        let sample = DebugFixtures.apps.filter { [DebugFixtures.AppID.parcel, DebugFixtures.AppID.quiet].contains($0.id) }
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + sample)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func theToolsAreInTheToolboxAndFree() {
        let names: Set = [
            "get_analytics_retention", "get_analytics_subscribers", "get_analytics_crashes", "get_analytics_after_download",
            "get_analytics_web_preview",
        ]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        #expect(names.allSatisfy { ProAssistantGate.refusal(forTool: $0, isPro: false) == nil })
    }

    @Test func retentionHasTheSaveRateAndEachMessage() async throws {
        let result = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(result["openedCancelScreen"] == .int(412))
        #expect(result["stayed"] == .int(94))
        #expect(result["report"]?["status"] == "ready")
        #expect(result["report"]?["sample"] == .bool(false))
        let messages = try #require(result["messages"]?.arrayValue)
        #expect(messages.last?["isNoMessage"] == .bool(true))
        #expect(messages.first?["againstNoMessage"]?.stringValue?.hasPrefix("higher") == true)
    }

    @Test func retentionWithFewPeopleIsTooFewToTell() async throws {
        let result = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Quiet Timer"]).result
        #expect(result["saveRate"]?["status"] == "tooFewToTell")
    }

    @Test func aReportSentEmptySaysSo() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Parcel Pal"])
        }
    }

    @Test func subscribersHaveBillingOffersAndPages() async throws {
        let result = try await call(GetAnalyticsSubscribersTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(result["billing"]?["couldNotBeCharged"] == .int(83))
        #expect(result["billing"]?["recovered"] == .int(29))
        #expect(result["billing"]?["lost"] == .int(54))
        #expect(result["billing"]?["billingGracePeriod"]?["on"] == .bool(false))
        let offers = try #require(result["offers"]?.arrayValue)
        #expect(offers.contains { $0["name"] == "PODCAST30" && $0["rate"]?["againstAverage"] == "worse" })
        let pages = try #require(result["byProductPage"]?.arrayValue).compactMap { $0["name"]?.stringValue }
        #expect(pages.contains("Mood tracking"))
    }

    @Test func crashesCompareTheNewestVersionWithTheOneBefore() async throws {
        let result = try await call(GetAnalyticsCrashesTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(result["latest"]?["version"] == "1.4")
        #expect(result["previous"]?["version"] == "1.3")
        #expect(result["againstPrevious"]?.stringValue?.hasPrefix("higher") == true)
        #expect(result["reports"]?.arrayValue?.first?["sample"] == .bool(true))
    }

    @Test func afterTheDownloadSplitsByPage() async throws {
        let result = try await call(GetAnalyticsAfterDownloadTool(store: store), ["appId": "Lumen Journal", "days": 28]).result
        #expect(result["all"]?["installs"] == .int(3100))
        let pages = try #require(result["byProductPage"]?.arrayValue)
        let mood = try #require(pages.first { $0["name"] == "Mood tracking" })
        #expect(mood["numbers"]?["deletions"] == .int(100))
    }

    // MARK: - by

    @Test func retentionBreaksDownBySubscriptionWithTheVerdictComputed() async throws {
        let result = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Lumen Journal", "by": "subscription"]).result
        #expect(result["by"] == "subscription")
        let rows = try #require(result["rows"]?.arrayValue)
        #expect(!rows.isEmpty)
        // The rows add up to the whole app.
        #expect(rows.compactMap { $0["opened"]?.intValue }.reduce(0, +) == 412)
        #expect(rows.allSatisfy { $0["saveRate"]?["status"] != nil })
        #expect(rows.allSatisfy { $0["messageAgainstNoMessage"] != nil })
        // The whole app's numbers stay.
        #expect(result["openedCancelScreen"] == .int(412))
    }

    @Test func retentionByMessageTypeHasNoMessageAgainstItself() async throws {
        let result = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Lumen Journal", "by": "messageType"]).result
        let rows = try #require(result["rows"]?.arrayValue)
        #expect(rows.allSatisfy { $0["messageAgainstNoMessage"] == nil })
    }

    @Test func subscribersByOneSplitReplaceTheDefaultLists() async throws {
        let result = try await call(GetAnalyticsSubscribersTool(store: store), ["appId": "Lumen Journal", "by": "campaign"]).result
        #expect(result["by"] == "campaign")
        #expect(result["byProductPage"] == nil)
        let names = try #require(result["rows"]?.arrayValue).compactMap { $0["name"]?.stringValue }
        let defaults = try await call(GetAnalyticsSubscribersTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(names == defaults["byCampaign"]?.arrayValue?.compactMap { $0["name"]?.stringValue })
    }

    @Test func afterTheDownloadSplitsByTerritory() async throws {
        let result = try await call(GetAnalyticsAfterDownloadTool(store: store), ["appId": "Lumen Journal", "by": "territory"]).result
        #expect(result["by"] == "territory")
        #expect(result["byAppVersion"] == nil)
        let rows = try #require(result["rows"]?.arrayValue)
        #expect(rows.contains { $0["name"] == "US" })
    }

    @Test func aBreakdownTheToolDoesntHaveIsRefused() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsRetentionTool(store: store), ["appId": "Lumen Journal", "by": "campaign"])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsAfterDownloadTool(store: store), ["appId": "Lumen Journal", "by": "subscription"])
        }
    }

    @Test func eachToolSaysWhatItBreaksDownBy() {
        for tool in [GetAnalyticsRetentionTool().definition, GetAnalyticsSubscribersTool().definition, GetAnalyticsAfterDownloadTool().definition] {
            #expect(tool.inputSchema["properties"]?["by"] != nil)
            #expect(tool.description.contains("`by`"))
        }
        #expect(AnalyticsMCPBreakdown.list(["territory", "device", "offer"]) == "territory, device or offer")
        #expect(AnalyticsMCPBreakdown.list(["device"]) == "device")
    }

    @Test func theWebPreviewCountsViewsAndTaps() async throws {
        let result = try await call(GetAnalyticsWebPreviewTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(result["pageViews"] == .int(1840))
        #expect(result["taps"] == .int(305))
    }

    @Test func addFindingKeepsWhatItRead() async throws {
        let tool = AddFindingTool(store: store)
        _ = try await call(tool, [
            "appId": "Lumen Journal", "area": "stability", "title": "1.4 crashes on iPad when opening an entry.",
            "why": "The crash rate tripled after 1.4.", "howSure": "26 crashes in 6,100 sessions against 20 in 15,400.", "read": ["get_analytics_crashes"],
        ])
        let finding = store.findings(for: DebugFixtures.AppID.lumen).fromAssistants.first { $0.area == .stability }
        #expect(finding?.read == ["get_analytics_crashes"])
    }
}
#endif
