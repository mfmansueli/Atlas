//
//  PricingProductCardTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A product's card on Pricing's Prices page, read from Lumen Plus Annual's
/// sample matrix: how its prices are set, its open price suggestion, and
/// what Keep my prices, Dismiss and accepting do to it.
@MainActor
@Suite("Pricing product card")
struct PricingProductCardTests {
    private func card(_ matrix: PriceMatrixModel, isDismissed: Bool = false) -> PricingProductCard {
        PricingProductCard.make(product: matrix.product, rows: matrix.rows, showsSuggestions: matrix.showsSuggestions, isDismissed: isDismissed)
    }

    @Test func everyCountryIsCountedOnce() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let card = card(matrix)
        #expect(card.territoryCount == matrix.rows.count)
        #expect(card.equalizedCount + card.customCount + card.suggestedCount + card.queuedCount == card.territoryCount)
        #expect(card.prices.count == matrix.rows.count)
        #expect(card.legend.hasPrefix("\(matrix.rows.count) countries and regions"))
        #expect(card.kindText == "Subscription · \(matrix.product.durationText)")
        #expect(card.baseTerritoryText == "in the United States")
        #expect(card.basePrice != nil)
    }

    @Test func theRecommendedStrategyLowersPricesInTheMostVisitedCountriesFirst() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let card = card(matrix)
        let suggestion = try #require(card.suggestion)
        #expect(suggestion.count == card.suggestedCount)
        #expect(suggestion.title.hasPrefix("Lower the price in"))
        #expect(suggestion.countries.count == min(PricingProductCard.listedCountryCount, suggestion.count))
        #expect(suggestion.moreCount == suggestion.count - suggestion.countries.count)
        let views = suggestion.countries.map { id in matrix.rows.first { $0.id == id.id }?.pageViews ?? 0 }
        #expect(views == views.sorted(by: >))
        #expect(suggestion.countries.allSatisfy { $0.change.hasPrefix("−") })
        let listed = try #require(suggestion.countries.first)
        #expect(card.prices[listed.id]?.next == listed.suggested)
        #expect(card.prices[listed.id]?.isQueued == false)
        #expect(card.prices[listed.id]?.dollars != nil)
    }

    @Test func theWhyNamesTheCountryWhosePriceMovesMost() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let candidates = matrix.rows.filter { !$0.isBase && $0.recommendation != nil }
        let small = try Self.suggesting(#require(candidates.first), share: Decimal(99) / 100, reason: "Small step")
        let large = try Self.suggesting(#require(candidates.dropFirst().first), share: Decimal(60) / 100, reason: "Big step")
        let card = PricingProductCard.make(product: matrix.product, rows: [small, large], showsSuggestions: true, isDismissed: false)
        let suggestion = try #require(card.suggestion)
        #expect(suggestion.count == 2)
        #expect(suggestion.reason == "\(large.territory.name): Big step")
        #expect(PricingProductCard.mostTelling([small, large])?.id == large.id)
    }

    @Test func aDismissedSuggestionOrKeepMyPricesShowsNone() async throws {
        let matrix = try await PricingModelFixtures.matrix()
        let dismissed = card(matrix, isDismissed: true)
        #expect(dismissed.suggestion == nil)
        #expect(dismissed.suggestedCount == 0)
        #expect(dismissed.prices.values.allSatisfy { $0.next == nil })

        let kept = try await PricingModelFixtures.matrix(mode: .keepPrices)
        #expect(card(kept).suggestion == nil)
    }

    @Test func acceptedPricesWaitAsNotPushed() async throws {
        let matrix = try await PricingModelFixtures.matrix(follows: true)
        let card = card(matrix)
        #expect(card.suggestion == nil)
        #expect(card.hasQueuedChanges)
        #expect(card.legend.contains("\(card.queuedCount) not pushed"))
        let brazil = try #require(card.prices["BRA"])
        #expect(brazil.next != nil)
        #expect(brazil.isQueued)
    }

    /// The row with a suggestion at `share` of today's price that doesn't
    /// feel 25%+ above the base, so the why names one country.
    private static func suggesting(_ row: PricingRow, share: Decimal, reason: String) -> PricingRow {
        var row = row
        row.usesCustomStrategy = false
        row.queued = nil
        guard var recommendation = row.recommendation else { return row }
        let price = row.current.customerPrice * share
        recommendation.price = PricePoint(customerPrice: price, proceeds: price)
        recommendation.isUnchanged = false
        recommendation.ratio = 1
        recommendation.reason = reason
        row.recommendation = recommendation
        return row
    }
}
#endif
