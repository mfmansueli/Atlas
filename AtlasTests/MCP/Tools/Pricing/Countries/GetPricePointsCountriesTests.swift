//
//  GetPricePointsCountriesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_price_points` as the price popover lists points: IDs, dollars,
/// the automatic and suggested points, several countries, a range and
/// points around a dollar amount.
@MainActor
@Suite("get_price_points: countries")
struct GetPricePointsCountriesTests {
    private typealias Fixtures = MCPPricingFixtures

    private func call(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = .string(Fixtures.annual)
        return try await Fixtures.call(GetPricePointsTool(), arguments)
    }

    @Test func pointsCarryTheirIDAndDollars() async throws {
        let outcome = try await call(["territory": "BRA"])
        let points = try #require(outcome.result["points"]?.arrayValue)
        #expect(points.allSatisfy { $0["pricePointId"]?.stringValue?.hasPrefix("debug-") == true })
        #expect(points.allSatisfy { ($0["usd"]?.doubleValue ?? 0) > 0 })
        #expect(outcome.result["setBy"] != nil)
        #expect(outcome.result["suggested"] == .double(109.9))
    }

    @Test func theAutomaticPointIsMarked() async throws {
        let sheet = try Fixtures.sheet(Fixtures.annual)
        let equalized = try #require(sheet.prices["MEX"]?.equalized.customerPrice)
        let outcome = try await call(["territory": "MEX", "near": MCPPriceValue.json(equalized)])
        let points = try #require(outcome.result["points"]?.arrayValue)
        #expect(points.contains { $0["automatic"] == true && $0["price"] == MCPPriceValue.json(equalized) })
        #expect(outcome.result["automaticPrice"] == MCPPriceValue.json(equalized))
    }

    @Test func severalCountriesAtOnce() async throws {
        let outcome = try await call(["territories": ["BRA", "IND"]])
        let list = try #require(outcome.result["territories"]?.arrayValue)
        #expect(list.compactMap { $0["territory"]?.stringValue } == ["BRA", "IND"])
    }

    @Test func tooManyCountriesAreRefused() async throws {
        await #expect(throws: MCPToolError.self) { try await call(["territories": "all"]) }
    }

    @Test func everyPointInARange() async throws {
        let outcome = try await call(["territory": "BRA", "min": 100, "max": 120])
        let prices = try #require(outcome.result["points"]?.arrayValue).compactMap { $0["price"]?.doubleValue }
        #expect(!prices.isEmpty)
        #expect(prices.allSatisfy { $0 >= 100 && $0 <= 120 })
        await #expect(throws: MCPToolError.self) { try await call(["territory": "BRA", "min": 100]) }
        await #expect(throws: MCPToolError.self) { try await call(["territory": "BRA", "min": 120, "max": 100]) }
    }

    @Test func pointsAroundADollarAmount() async throws {
        let outcome = try await call(["territory": "BRA", "nearUsd": 20])
        let dollars = try #require(outcome.result["points"]?.arrayValue).compactMap { $0["usd"]?.doubleValue }
        #expect(dollars.contains { $0 < 20 })
        #expect(dollars.contains { $0 >= 20 })
    }

    @Test func aDollarAmountInACurrency() {
        let price = MCPPricePointWindow.price(ofDollars: 10, currency: "BRL")
        #expect(price == 55)
        #expect(MCPPricePointWindow.price(ofDollars: 10, currency: "XXX") == nil)
    }
}
#endif
