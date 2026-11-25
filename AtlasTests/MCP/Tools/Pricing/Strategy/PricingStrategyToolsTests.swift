//
//  PricingStrategyToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_pricing_strategy` and `propose_pricing_strategy`: the app's own
/// mode and strategy, read as Pricing → Customize… shows them, and a
/// suggestion that waits as a card in Pricing until the person accepts it.
@MainActor
@Suite("Pricing strategy MCP tools")
struct PricingStrategyToolsTests {
    private let modes = PricingModeStore(defaults: nil)
    private let lumen = MCPTestFixtures.apps[0]

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        let workspace = MCPTestFixtures.workspace(pricingModes: modes)
        return try await tool.call(MCPToolArguments(all), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
    }

    @Test func theStrategyIsReadWithItsRanges() async throws {
        let outcome = try await call(GetPricingStrategyTool(), [:])
        #expect(outcome.result["mode"] == .string(modes.mode(for: lumen.id).rawValue))
        #expect(outcome.result["strategy"] != nil)
        #expect(outcome.result["limits"] != nil)
        #expect(outcome.logLines.first?.outcome == .read)
    }

    @Test func aNewModeWaitsAsASuggestionAndChangesNothingYet() async throws {
        let before = modes.mode(for: lumen.id)
        let next: PricingMode = before == .keepPrices ? .showSuggestions : .keepPrices
        let outcome = try await call(ProposePricingStrategyTool(), [
            "mode": .string(next.rawValue), "title": "Keep today’s prices", "why": "Sales rose 12% since the last change.",
        ])
        #expect(outcome.result["status"] == "suggested")
        let suggestion = try #require(modes.strategySuggestion(for: lumen.id))
        #expect(suggestion.mode == next)
        #expect(suggestion.source == "Claude Code")
        #expect(modes.mode(for: lumen.id) == before)
        #expect(outcome.result["changes"]?.arrayValue?.isEmpty == false)
    }

    @Test func aStrategyEditIsAppliedOverTheAppsStrategy() async throws {
        modes.setMode(.showSuggestions, for: lumen.id)
        let outcome = try await call(ProposePricingStrategyTool(), [
            "strategy": ["method": "priceIndex", "intensity": .double(0.5)], "title": "Half the index", "why": "Europe converts 30% less.",
        ])
        #expect(outcome.result["status"] == "suggested")
        let strategy = try #require(modes.strategySuggestion(for: lumen.id)?.strategy)
        #expect(strategy != modes.strategy(for: lumen.id))
    }

    @Test func nothingToChangeIsRefused() async throws {
        let outcome = try await call(ProposePricingStrategyTool(), [
            "mode": .string(modes.mode(for: lumen.id).rawValue), "title": "Same", "why": "No reason.",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(modes.strategySuggestion(for: lumen.id) == nil)
    }

    @Test func aRangeOutsideTheLimitsThrows() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposePricingStrategyTool(), [
                "strategy": ["intensity": .double(3)], "title": "Too much", "why": "Test.",
            ])
        }
    }

    @Test func withdrawTakesBackOnlyYourOwn() async throws {
        modes.setMode(.showSuggestions, for: lumen.id)
        _ = try await call(ProposePricingStrategyTool(), ["mode": "keepPrices", "title": "Keep prices", "why": "Sales rose 12%."])
        let withdrawn = try await call(ProposePricingStrategyTool(), ["withdraw": true])
        #expect(withdrawn.result["status"] == "withdrawn")
        #expect(modes.strategySuggestion(for: lumen.id) == nil)
        let again = try await call(ProposePricingStrategyTool(), ["withdraw": true])
        #expect(again.result["status"] == "refused")
    }

    @Test func theStoreKeepsTheAppsOwnStrategyApartFromTheDefaults() {
        #expect(!modes.hasOwnStrategy(lumen.id))
        var strategy = modes.strategy(for: lumen.id)
        strategy.floor = 0.5
        modes.setStrategy(strategy, for: lumen.id)
        #expect(modes.hasOwnStrategy(lumen.id))
        #expect(modes.strategy(for: lumen.id).floor == 0.5)
        #expect(modes.strategy(for: "other") == modes.defaultStrategy)
    }
}
