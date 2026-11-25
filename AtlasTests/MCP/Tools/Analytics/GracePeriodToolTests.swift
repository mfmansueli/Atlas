//
//  GracePeriodToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_grace_period`: a suggestion that waits in Analytics → Billing
/// and Plans; only the person turns Billing Grace Period on.
@MainActor
@Suite("Billing Grace Period over MCP")
struct GracePeriodToolTests {
    private let suggestions = GracePeriodSuggestionStore()
    private let lumen = MCPTestFixtures.apps[0]

    private func call(_ arguments: [String: JSONValue], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)) async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        var context = MCPToolContext(workspace: MCPTestFixtures.workspace(), clientName: "Claude Code")
        context.allowedProposals = allowed
        return try await ProposeGracePeriodTool(suggestions: suggestions).call(MCPToolArguments(all), in: context)
    }

    @Test func onlyThreeSixteenOrTwentyEightDays() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(["days": 7, "why": "41 left over failed charges."])
        }
        #expect(GracePeriodSetting.Duration.allCases.map(\.days).sorted() == [3, 16, 28])
    }

    @Test func withoutPricesPermissionItsRefused() async throws {
        let outcome = try await call(["days": 16, "why": "41 left over failed charges."], allowed: [])
        #expect(outcome.result["status"] == "refused")
        #expect(suggestions.suggestion(for: lumen.id) == nil)
    }

    @Test func withdrawTakesBackOnlyYourOwn() async throws {
        let none = try await call(["withdraw": true])
        #expect(none.result["status"] == "refused")
        suggestions.suggest(GracePeriodSuggestion(appID: lumen.id, duration: .sixteenDays, why: "41 left.", client: "Claude Code"))
        let withdrawn = try await call(["withdraw": true])
        #expect(withdrawn.result["status"] == "withdrawn")
        #expect(suggestions.suggestion(for: lumen.id) == nil)
    }

    @Test func itOffersHowSureAndRefusesOneOutOfRange() async throws {
        #expect(ProposeGracePeriodTool().definition.inputSchema.jsonString().contains("\"confidence\""))
        await #expect(throws: MCPToolError.self) {
            _ = try await call(["days": 16, "why": "41 left over failed charges.", "confidence": 7])
        }
        #expect(suggestions.suggestion(for: lumen.id) == nil)
    }

    @Test func anotherAssistantsSuggestionStays() async throws {
        suggestions.suggest(GracePeriodSuggestion(appID: lumen.id, duration: .threeDays, why: "12 left.", client: "Codex"))
        let outcome = try await call(["withdraw": true])
        #expect(outcome.result["status"] == "refused")
        #expect(suggestions.suggestion(for: lumen.id)?.client == "Codex")
    }
}
