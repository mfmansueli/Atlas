//
//  PricingStrategyDataTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// get_pricing_strategy says what the suggestions stand on: each index's
/// edition, the exchange rates' date and source, and how sure's thresholds.
@MainActor
@Suite("get_pricing_strategy · data")
struct PricingStrategyDataTests {
    @Test func theDataNamesEachIndexEdition() async throws {
        let outcome = try await MCPPricingFixtures.call(GetPricingStrategyTool(), ["appId": .string(MCPPricingFixtures.lumen)])
        let data = try #require(outcome.result["data"])
        #expect(data["approximate"] == true)
        let indices = try #require(data["indices"]?.arrayValue)
        let worldBank = try #require(indices.first { $0["source"] == "worldBank" })
        #expect(worldBank["edition"] == "2024 data, published 2025")
        #expect(worldBank["label"] == "World Bank 2024")
        #expect(worldBank["published"] == "2025-07-01")
        #expect((worldBank["coverage"]?.intValue ?? 0) > 100)
        #expect(worldBank["stale"] != nil)
        #expect(data["exchangeRates"]?["source"]?.stringValue?.isEmpty == false)
    }

    @Test func theHowSureRuleHasItsNumbers() {
        let rule = MCPPricingDataJSON.howSureRule
        #expect(rule["fairlySure"]?["pageViews"] == 300)
        #expect(rule["fairlySure"]?["trialStarts"] == 10)
        #expect(rule["fairlySure"]?["days"] == 90)
        #expect(rule["sure"]?["daysEachSide"] == 28)
        #expect(rule["sure"]?["startsEachSide"] == 30)
        #expect(rule["staleAfterMonths"] == 18)
    }

    @Test func aStaleEditionIsMarked() throws {
        let snapshot = PricingSampleData.shared.snapshot
        let index = try #require(snapshot.index(.worldBank))
        let later = Calendar.gmtGregorian.date(byAdding: .month, value: 19, to: index.edition.date) ?? .now
        #expect(MCPPricingDataJSON.index(.worldBank, index, asOf: later)["stale"] == true)
        #expect(MCPPricingDataJSON.index(.worldBank, index, asOf: index.edition.date)["stale"] == false)
    }
}
#endif
