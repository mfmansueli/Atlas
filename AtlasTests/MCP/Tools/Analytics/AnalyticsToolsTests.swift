//
//  AnalyticsToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_analytics_funnel`, `get_analytics_breakdown`,
/// `get_analytics_subscriptions` and `add_finding`, against the sample
/// account's canned Analytics.
@MainActor
@Suite("Analytics MCP tools")
struct AnalyticsToolsTests {
    private let store = DebugAnalyticsData.store()

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: MCPTestFixtures.workspace(), clientName: "Claude Code"))
    }

    @Test func theToolsAreInTheToolbox() {
        let names: Set = ["get_analytics_funnel", "get_analytics_breakdown", "get_analytics_subscriptions", "add_finding"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        // Reading and saying why are part of Free.
        #expect(names.allSatisfy { ProAssistantGate.refusal(forTool: $0, isPro: false) == nil })
        #expect(MCPEndpoint.instructions.contains("get_analytics_"))
    }

    @Test func theFunnelHasEveryStepWithItsRange() async throws {
        let outcome = try await call(GetAnalyticsFunnelTool(store: store), ["appId": "Lumen Journal"])
        let result = outcome.result
        #expect(result["period"]?["through"] == "2026-11-09")
        #expect(result["period"]?["days"] == .int(28))
        let steps = try #require(result["steps"]?.arrayValue)
        #expect(steps.compactMap { $0["step"]?.stringValue } == ["impressions", "pageViews", "downloads", "trials", "paid"])
        let views = steps[1]
        #expect(views["rateFromPreviousStep"]?["status"] == "measured")
        #expect(views["rateFromPreviousStep"]?["sureness"] == "sure")
        #expect(views["againstPrevious"]?["outcome"] == "lowerSure")
        #expect(steps[0]["rateFromPreviousStep"] == nil)
        #expect(result["findings"]?.arrayValue?.first?["source"] == "Claude Code")
        #expect(result["notes"]?.arrayValue?.isEmpty == false)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
    }

    @Test func theFunnelSaysWhatIsMissing() async throws {
        let store = DebugAnalyticsData.store(vendorNumber: "", hasSales: false)
        let result = try await call(GetAnalyticsFunnelTool(store: store), ["appId": "Lumen Journal", "days": 7]).result
        let trials = try #require(result["steps"]?.arrayValue?[3])
        #expect(trials["count"] == .null)
        #expect(trials["missing"] == "Needs your vendor number")
        let notes = result["notes"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(notes.contains { $0.contains("vendor number") })
    }

    @Test func anAppWithoutAnalyticsSaysHowToTurnItOn() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsFunnelTool(store: store), ["appId": "Fieldnote"])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsFunnelTool(store: store), ["appId": "Lumen Journal", "days": 30])
        }
    }

    @Test func theBreakdownComparesTerritoriesWithTheAverage() async throws {
        let result = try await call(GetAnalyticsBreakdownTool(store: store), ["appId": "Lumen Journal", "limit": 5]).result
        #expect(result["by"] == "territory")
        let rows = try #require(result["rows"]?.arrayValue)
        #expect(rows.count == 5)
        #expect(result["rowsLeftOut"] == .int(10))
        #expect(rows.first?["id"] == "US")
        let germany = try #require(rows.first { $0["id"] == "DE" })
        #expect(germany["downloadRate"]?["againstAverage"] == "worse")
        #expect(germany["pageLocale"] == "de-DE")
        #expect(germany["pageText"] == "machineTranslated")
        #expect(germany["price"]?["now"] == "39,99 €")
    }

    @Test func sourcesHaveNoSubscriptions() async throws {
        let result = try await call(GetAnalyticsBreakdownTool(store: store), ["appId": "Lumen Journal", "by": "source"]).result
        let search = try #require(result["rows"]?.arrayValue?.first)
        #expect(search["name"] == "App Store Search")
        #expect(search["subscriptionStarts"] == .null)
        #expect(search["startRate"]?["status"] == "missing")
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsBreakdownTool(store: store), ["appId": "Lumen Journal", "by": "weekday"])
        }
    }

    @Test func subscriptionsHaveRenewalsCancellationsAndTerritories() async throws {
        let result = try await call(GetAnalyticsSubscriptionsTool(store: store), ["appId": "Lumen Journal"]).result
        #expect(result["trialToPaid"]?["status"] == "measured")
        #expect(result["renewals"]?.arrayValue?.count == 6)
        #expect((result["cancellations"]?["total"]?.intValue ?? 0) > 0)
        #expect(result["liveRetentionMessages"] == .int(0))
        #expect(result["subscriptions"]?.arrayValue?.count == 2)
        #expect(result["territories"]?.arrayValue?.isEmpty == false)
        // Without the vendor number there's nothing to read, and it says so.
        let noSales = DebugAnalyticsData.store(vendorNumber: "", hasSales: false)
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAnalyticsSubscriptionsTool(store: noSales), ["appId": "Lumen Journal"])
        }
    }

    @Test func aFindingLandsInWhatToTryMarkedAsTheAssistants() async throws {
        let outcome = try await call(AddFindingTool(store: store), [
            "appId": "Lumen Journal",
            "title": "Japan opens the page less often than average.",
            "why": "The Japanese subtitle repeats the app's name.",
            "area": "storePage",
            "locale": "ja",
            "howSure": "552 page views from 12,900 impressions.",
            "sureness": "rough",
            "numbers": [["label": "View rate", "value": "4.1%", "note": "Lumen 4.9%"]],
            "id": "cc.japan",
        ])
        #expect(outcome.result["status"] == "added")
        #expect(outcome.result["id"] == "cc.japan")
        let finding = try #require(store.findings(for: DebugFixtures.AppID.lumen).fromAssistants.first)
        #expect(finding.source == .assistant("Claude Code"))
        #expect(finding.action == .storePage(locale: "ja"))
        #expect(finding.sureness == "Rough")
        #expect(finding.numbers == [FindingNumber(label: "View rate", value: "4.1%", note: "Lumen 4.9%")])
        #expect(store.findings(for: DebugFixtures.AppID.lumen).isNew(finding))

        // The same id replaces it.
        _ = try await call(AddFindingTool(store: store), [
            "appId": "Lumen Journal", "title": "Japan opens the page less often.", "why": "Same.", "area": "storePage",
            "howSure": "As before.", "id": "cc.japan",
        ])
        #expect(store.findings(for: DebugFixtures.AppID.lumen).fromAssistants.count { $0.id == "cc.japan" } == 1)
    }

    @Test func aFindingThatCantStandIsRefusedWithTheReason() async throws {
        let base: [String: JSONValue] = ["appId": "Lumen Journal", "title": "T", "why": "W", "area": "pricing", "howSure": "H"]
        var long = base
        long["title"] = .string(String(repeating: "x", count: 141))
        #expect(try await call(AddFindingTool(store: store), long).result["status"] == "refused")
        var territory = base
        territory["territory"] = "ZZ"
        #expect(try await call(AddFindingTool(store: store), territory).result["reason"]?.stringValue?.contains("ZZ") == true)
        var off = base
        off["appId"] = "Fieldnote"
        #expect(try await call(AddFindingTool(store: store), off).result["status"] == "refused")
        var area = base
        area["area"] = "marketing"
        await #expect(throws: MCPToolError.self) { _ = try await call(AddFindingTool(store: store), area) }
    }
}
#endif
