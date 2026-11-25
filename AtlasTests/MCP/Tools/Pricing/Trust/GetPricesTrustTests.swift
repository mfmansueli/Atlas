//
//  GetPricesTrustTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// get_prices says what each price stands on: how sure Atlas is and why,
/// the sales behind it, and on request the index value, exchange rate and
/// Apple's grid; per product the sales state, the weighted how sure and
/// the suggestion count.
@MainActor
@Suite("get_prices · trust")
struct GetPricesTrustTests {
    private typealias Fixtures = MCPPricingFixtures

    private func read(
        _ arguments: [String: JSONValue] = [:],
        product: String = Fixtures.annual,
        pricing: (any PricingServices)? = nil
    ) async throws -> JSONValue {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = .string(product)
        let outcome = try await Fixtures.call(GetPricesTool(), arguments, pricing: pricing)
        return try #require(outcome.result["products"]?.arrayValue?.first)
    }

    private func territory(_ code: String, in product: JSONValue) throws -> JSONValue {
        try #require(product["territories"]?.arrayValue?.first { $0["territory"]?.stringValue == code })
    }

    private func scenario(_ scenario: DebugPricingConfidenceSales.Scenario) -> DebugConfidencePricingServices {
        DebugConfidencePricingServices(scenario: scenario)
    }

    // MARK: - Fields

    @Test func byDefaultEachCountryHasHowSureAndEvidenceOnly() async throws {
        let brazil = try await territory("BRA", in: read(pricing: scenario(.fairly)))
        let howSure = try #require(brazil["howSure"])
        #expect(howSure["level"] == "fairlySure")
        #expect(howSure["word"] == "Fairly sure")
        #expect(howSure["confidence"] == 2)
        #expect(howSure["reason"]?.stringValue?.hasPrefix("Brazil: ") == true)
        #expect(brazil["evidence"]?["days90"]?["pageViews"] == 2400)
        #expect(brazil["evidence"]?["days90"]?["trialStarts"] == 40)
        #expect(brazil["evidence"]?["days90"]?["paidStarts"] == 15)
        #expect(brazil["evidence"]?["days28"]?["pageViews"] == 720)
        #expect(brazil["evidence"]?["days90"]?["proceedsUSD"] != nil)
        #expect(brazil["index"] == nil)
        #expect(brazil["exchangeRate"] == nil)
        #expect(brazil["grid"] == nil)
    }

    @Test func includeAllAddsTheIndexTheRateAndTheGrid() async throws {
        let readOn = PricingSampleData.date("2026-11-20")
        var services = DebugPricingServices()
        services.laddersReadOn = readOn
        let brazil = try await territory("BRA", in: read(["include": ["all"]], pricing: services))

        let index = try #require(brazil["index"])
        #expect(index["basis"] == "index")
        #expect(index["source"] == "worldBank")
        #expect(index["label"]?.stringValue?.isEmpty == false)
        #expect(index["trust"] == "approximate")
        #expect((index["factor"]?.doubleValue ?? 0) > 0)
        #expect(brazil["exchangeRate"]?["currency"] == "BRL")
        #expect((brazil["exchangeRate"]?["perDollar"]?.doubleValue ?? 0) > 0)
        let grid = try #require(brazil["grid"])
        #expect(grid["real"] == true)
        #expect(grid["readAt"] == .string(readOn.formatted(.iso8601)))
        #expect(grid["suggestedPoint"]?["customerPrice"] == .double(109.9))
        #expect(grid["suggestedPoint"]?["proceeds"] != nil)
        #expect(grid["suggestedPoint"]?["pricePointId"]?.stringValue?.hasPrefix("debug-") == true)
    }

    @Test func includeTakesSomeGroups() async throws {
        let brazil = try await territory("BRA", in: read(["include": ["grid"]]))
        #expect(brazil["grid"] != nil)
        #expect(brazil["howSure"] == nil)
        #expect(brazil["evidence"] == nil)
    }

    @Test func anUnknownGroupIsRefused() async throws {
        await #expect(throws: MCPToolError.invalidArgument(name: "include", expected: "a list of howSure, evidence, index, exchangeRate, grid or all")) {
            try await read(["include": ["everything"]])
        }
    }

    @Test func theTerritoryFilterStillApplies() async throws {
        let product = try await read(["territories": ["BRA", "DEU"]], pricing: scenario(.fairly))
        #expect(product["territories"]?.arrayValue?.count == 2)
    }

    @Test func theAnswerNamesTheExchangeRates() async throws {
        let outcome = try await Fixtures.call(GetPricesTool(), ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual)])
        let rates = try #require(outcome.result["exchangeRates"])
        #expect(rates["source"]?.stringValue?.isEmpty == false)
        #expect(rates["line"]?.stringValue?.isEmpty == false)
    }

    // MARK: - Sales states

    @Test func noSalesYetIsPurchasingPowerAlone() async throws {
        let product = try await read(pricing: scenario(.noSales))
        let sales = try #require(product["trust"]?["sales"])
        #expect(sales["availability"] == "noSalesYet")
        #expect(sales["line"] == "No sales yet, so purchasing power alone.")
        #expect(sales["readThrough"] == "2026-11-22")
        let brazil = try territory("BRA", in: product)
        #expect(brazil["howSure"]?["level"] == "notVerySure")
        #expect(brazil["howSure"]?["confidence"] == 1)
        #expect(brazil["howSure"]?["reason"] == "Purchasing power only: no sales yet.")
        #expect(brazil["evidence"]?["days90"]?["pageViews"] == 9)
        #expect(brazil["evidence"]?["days90"]?["starts"] == 0)
    }

    @Test func aKeyThatCantReadSalesHasNoEvidence() async throws {
        var services = DebugPricingServices()
        services.canReadSales = false
        let product = try await read(pricing: services)
        #expect(product["trust"]?["sales"]?["availability"] == "roleCannotRead")
        #expect(product["trust"]?["sales"]?["line"] == "Purchasing power alone: this key’s role can’t read Sales and Trends.")
        let brazil = try territory("BRA", in: product)
        #expect(brazil["evidence"] == nil)
        #expect(brazil["howSure"]?["reason"] == "Purchasing power only: this key’s role can’t read sales.")
    }

    @Test func aThinCountryBorrowsFromItsRegion() async throws {
        let portugal = try await territory("PRT", in: read(pricing: scenario(.thin)))
        #expect(portugal["howSure"]?["level"] == "fairlySure")
        let borrowed = try #require(portugal["evidence"]?["borrowedFrom"])
        #expect(borrowed["region"] == "europe")
        #expect(borrowed["name"] == "Europe")
        #expect((borrowed["days90"]?["pageViews"]?.intValue ?? 0) >= PriceConfidenceRule.minimumPageViews)
        #expect(portugal["evidence"]?["days90"]?["pageViews"] == 40)
    }

    @Test func anEarlierChangeMakesItSure() async throws {
        let product = try await read(pricing: scenario(.sure))
        let brazil = try territory("BRA", in: product)
        #expect(brazil["howSure"]?["level"] == "sure")
        #expect(brazil["howSure"]?["reason"]?.stringValue?.hasPrefix("Your May change: 41 → 70 starts") == true)
        #expect(brazil["evidence"]?["earlierChange"]?["date"] == "2026-05-12")
        #expect(brazil["evidence"]?["earlierChange"]?["before28"]?["starts"] == 41)
        #expect(brazil["evidence"]?["earlierChange"]?["after28"]?["starts"] == 70)
        #expect(product["trust"]?["howSure"]?["level"] == "sure")
    }

    // MARK: - Product

    @Test func theProductCountsItsSuggestionsAndWeighsHowSure() async throws {
        let product = try await read(pricing: scenario(.fairly))
        let trust = try #require(product["trust"])
        #expect((trust["suggestions"]?.intValue ?? 0) > 0)
        #expect(trust["howSure"]?["word"] != nil)
        #expect(trust["sales"]?["availability"] == "available")
        #expect(trust["matchLine"] == nil)
    }

    @Test func withNothingSuggestedTheMatchLineShows() async throws {
        let product = try await read(pricing: scenario(.matched))
        let trust = try #require(product["trust"])
        #expect(trust["suggestions"] == 0)
        #expect(trust["howSure"] == nil)
        #expect(trust["matchLine"]?.stringValue?.hasPrefix("Your prices match local purchasing power in ") == true)
    }

    @Test func anInAppPurchaseHasHowSureButNoSuggestions() async throws {
        let product = try await read(product: Fixtures.lifetime)
        #expect(product["trust"]?["suggestions"] == 0)
        #expect(product["trust"]?["howSure"] == nil)
        let usa = try territory("USA", in: product)
        #expect(usa["howSure"]?["level"] != nil)
    }

    @Test func theBaseTerritoryHasAHowSureToo() async throws {
        let usa = try await territory("USA", in: read(pricing: scenario(.fairly)))
        #expect(usa["howSure"]?["level"] == "fairlySure")
        #expect(usa["suggested"] == nil)
    }

    // MARK: - Description

    @Test func theDescriptionAndHintNameTheNewFields() {
        let tool = GetPricesTool()
        #expect(tool.definition.description.contains("howSure"))
        #expect(tool.definition.inputSchema.jsonString().contains("\"include\""))
        for field in ["howSure", "evidence", "borrowedFrom", "trust", "noSalesYet", "readAt", "suggestedPoint", "dataYear"] {
            #expect(GetPricesTool.hint.contains(field), "\(field)")
        }
    }
}
#endif
