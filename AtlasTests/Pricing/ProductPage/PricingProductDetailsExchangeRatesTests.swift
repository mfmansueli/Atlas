//
//  PricingProductDetailsExchangeRatesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 76: the exchange rates' source and day show in the product's
/// Details (and the Prices by Country footer), never in the banner.
@MainActor
@Suite("Pricing product details · exchange rates")
struct PricingProductDetailsExchangeRatesTests {
    private let catalog = DebugPricingCatalog.catalog(for: PricingModelFixtures.appID)

    @Test func theRatesRowSitsBeforeTheTaxCategory() throws {
        let annual = try #require(catalog.product(id: DebugPricingCatalog.lumenAnnualID))
        let rates = ExchangeRates(unitsPerDollar: ["USD": 1], date: PricingSampleData.date("2026-11-25"), source: .exchangeRateAPI)
        let details = PricingProductDetails.make(
            product: annual,
            group: catalog.group(containing: annual.id),
            basePrice: "$39.99 in the United States",
            isReadingPrices: false,
            facts: .loaded(PricingProductFacts(availableTerritoryCount: 175, availableInNewTerritories: true, isFamilySharable: false)),
            territoryTotal: 175,
            exchangeRates: rates
        )
        let kinds = details.rows.map(\.kind)
        #expect(kinds.suffix(3) == [.commission, .exchangeRates, .taxCategory])
        #expect(details.rows.first { $0.kind == .exchangeRates }?.value == rates.sourceLine)
    }

    @Test func withoutRatesThereIsNoRow() throws {
        let annual = try #require(catalog.product(id: DebugPricingCatalog.lumenAnnualID))
        let details = PricingProductDetails.make(
            product: annual, group: nil, basePrice: nil, isReadingPrices: false, facts: .idle, territoryTotal: 175
        )
        #expect(!details.rows.contains { $0.kind == .exchangeRates })
    }
}
#endif
