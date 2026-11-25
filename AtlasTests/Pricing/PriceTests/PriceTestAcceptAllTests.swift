//
//  PriceTestAcceptAllTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A country in a running price test has no suggestion, so Accept All
/// leaves it out, and the line says how many it held back.
@MainActor
@Suite("Price tests and Accept All")
struct PriceTestAcceptAllTests {
    @Test func aTestCountryKeepsItsPriceAndIsHeldBack() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let suggested = try #require(matrix.rows.first { $0.hasSuggestion && !$0.isBase })
        matrix.priceTestTerritories = [suggested.id]
        let row = try #require(matrix.rows.first { $0.id == suggested.id })
        #expect(row.isInPriceTest)
        #expect(!row.hasSuggestion)
        #expect(row.target == row.current)
        #expect(row.isHeldBackByPriceTest)
        // The others still follow the strategy.
        #expect(matrix.rows.filter(\.hasSuggestion).count == matrix.rows.filter { $0.id != suggested.id && $0.hasSuggestion }.count)
    }

    @Test func aCountryWithoutASuggestionIsntHeldBack() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let steady = try #require(matrix.rows.first { !$0.hasSuggestion && !$0.isBase })
        matrix.priceTestTerritories = [steady.id]
        let row = try #require(matrix.rows.first { $0.id == steady.id })
        #expect(row.isInPriceTest)
        #expect(!row.isHeldBackByPriceTest)
    }

    @Test func theBaseCountryIsNeverInATest() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let base = try #require(matrix.rows.first { $0.isBase })
        matrix.priceTestTerritories = [base.id]
        #expect(matrix.rows.first { $0.isBase }?.isHeldBackByPriceTest == false)
    }
}
#endif
