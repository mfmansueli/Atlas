//
//  GetPricesCountriesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_prices` reading countries as Prices by Country shows them: how
/// each is set, about how many dollars, Apple's automatic price, an in-app
/// purchase's queued prices, and only the countries asked for.
@MainActor
@Suite("get_prices: countries")
struct GetPricesCountriesTests {
    private typealias Fixtures = MCPPricingFixtures

    private func territories(_ arguments: [String: JSONValue], changes: ChangeQueue = ChangeQueue()) async throws -> [String: JSONValue] {
        let outcome = try await Fixtures.call(GetPricesTool(), arguments, changes: changes)
        let list = try #require(outcome.result["products"]?.arrayValue?.first?["territories"]?.arrayValue)
        return Dictionary(list.map { ($0["territory"]?.stringValue ?? "", $0) }) { first, _ in first }
    }

    @Test func eachCountrySaysHowItsSet() async throws {
        let rows = try await territories(["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual)])
        let usa = try #require(rows["USA"])
        #expect(usa["setBy"] == "basePrice")
        #expect(usa["automaticPrice"] == nil)
        #expect(usa["name"] == "United States")
        #expect(usa["region"] == "americas")
        #expect(usa["usd"] == .double(39.99))
        let mexico = try #require(rows["MEX"])
        #expect(mexico["setBy"] == "setByYou")
        #expect(mexico["automaticPrice"] != nil)
        let automatic = rows.values.filter { $0["setBy"] == "automatic" }
        #expect(!automatic.isEmpty)
        #expect(automatic.allSatisfy { $0["automaticPrice"] == nil })
    }

    @Test func onlyTheCountriesAsked() async throws {
        let rows = try await territories(["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "territories": ["BRA", "currency:GBP"]])
        #expect(Set(rows.keys) == ["BRA", "GBR"])
    }

    @Test func anInAppPurchasesQueuedPricesShow() async throws {
        let changes = ChangeQueue()
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.lifetime), "territory": "JPN", "automatic": true],
            changes: changes
        )
        let rows = try await territories(["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.lifetime)], changes: changes)
        let japan = try #require(rows["JPN"])
        #expect(japan["queuedAutomatic"] == true)
        #expect(japan["queuedBy"] == .string(Fixtures.client))
        #expect(japan["setBy"] == "automatic")
    }

    @Test func aDismissedSuggestionIsMarked() async throws {
        let modes = PricingModeStore(defaults: nil)
        modes.dismissCountrySuggestion(territoryID: "BRA", productID: Fixtures.annual, appID: Fixtures.lumen)
        let outcome = try await Fixtures.call(
            GetPricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "territories": "BRA"],
            pricingModes: modes
        )
        let brazil = try #require(outcome.result["products"]?.arrayValue?.first?["territories"]?.arrayValue?.first)
        #expect(brazil["suggested"] != nil)
        #expect(brazil["dismissed"] == true)
    }
}
#endif
