//
//  WorkspaceReadToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_settings`, `get_push_history` and `get_overview`: what an
/// assistant reads about Atlas itself, the pushes from this Mac and an
/// app at a glance. None of them writes.
@MainActor
@Suite("Workspace read tools")
struct WorkspaceReadToolsTests {
    private let lumen = MCPTestFixtures.apps[0]
    private let now = Date(timeIntervalSince1970: 1_794_830_400)

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue] = [:], workspace: MCPWorkspace = MCPTestFixtures.workspace(),
        allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        var context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        context.allowedProposals = allowed
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    // MARK: - Settings

    @Test func theSettingsSayWhatTheAssistantMaySuggest() async throws {
        var workspace = MCPTestFixtures.workspace(glossary: TranslationGlossary(terms: ["Lumen"]))
        workspace.isPro = { true }
        workspace.translationSource = { "en-US" }
        let outcome = try await call(GetSettingsTool(), workspace: workspace, allowed: [.prices])
        let result = outcome.result
        #expect(result["assistantMay"]?.arrayValue == [.string(MCPProposalKind.prices.rawValue)])
        #expect(result["assistantMayNot"]?.arrayValue?.count == MCPProposalKind.allCases.count - 1)
        #expect(result["pro"] == true)
        #expect(result["translation"]?["sourceLocale"] == "en-US")
        #expect(result["translation"]?["keepUntranslated"]?.arrayValue == ["Lumen"])
        #expect(result["client"] == "Claude Code")
        #expect(outcome.logLines.first?.outcome == .read)
    }

    @Test func proIsNullWhenAtlasCantTell() async throws {
        let outcome = try await call(GetSettingsTool())
        #expect(outcome.result["pro"] == .null)
        #expect(outcome.result["translation"]?["sourceLocale"] == .null)
    }

    // MARK: - Push history

    @Test func pushesAreReadNewestFirstForTheAppOnly() async throws {
        var workspace = MCPTestFixtures.workspace()
        let records = [
            PushRecord(date: now.addingTimeInterval(-3600), appID: lumen.id, appName: lumen.name, title: "Older", pushed: []),
            PushRecord(date: now, appID: lumen.id, appName: lumen.name, title: "Newer", pushed: []),
            PushRecord(date: now, appID: "6450000003", appName: "Tempo Metronome", title: "Other app", pushed: []),
        ]
        workspace.pushHistory = { records }
        let outcome = try await call(GetPushHistoryTool(), ["appId": "Lumen Journal", "limit": 1], workspace: workspace)
        #expect(outcome.result["count"] == .int(2))
        #expect(outcome.result["pushes"]?.arrayValue?.compactMap { $0["title"]?.stringValue } == ["Newer"])
        #expect(outcome.result["more"] == .int(1))
    }

    @Test func noPushesSaySo() async throws {
        let outcome = try await call(GetPushHistoryTool(), ["appId": "Lumen Journal"])
        #expect(outcome.result["count"] == .int(0))
        #expect(outcome.result["note"] != nil)
    }

    // MARK: - Overview

    @Test func theOverviewReadsEachPartAndWhatWaits() async throws {
        let outcome = try await call(GetOverviewTool(reviews: ReviewsStore()), ["appId": "Lumen Journal"])
        let result = outcome.result
        #expect(result["app"] == "Lumen Journal")
        #expect(result["storePage"] != nil)
        #expect(result["pricing"] != nil)
        #expect(result["appInformation"] != nil)
        #expect(result["waitingTotal"] == .int(0))
        #expect(result["reviews"] == nil)
        #expect(outcome.logLines.first?.outcome == .read)
    }
}
