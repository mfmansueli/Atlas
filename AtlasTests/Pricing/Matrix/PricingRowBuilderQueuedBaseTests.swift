//
//  PricingRowBuilderQueuedBaseTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Suggestions follow a new base price waiting in Review & Push (Alba, 25
/// Nov 2026: US$ 4.99 → 6.19 waiting).
@MainActor
@Suite("PricingRowBuilder · queued base price")
struct PricingRowBuilderQueuedBaseTests {
    private typealias Fixtures = PricingModelFixtures

    private func builder(queuedBase: Decimal? = nil) throws -> PricingRowBuilder {
        var builder = try PricingRowBuilder(
            catalog: .standard,
            calculator: PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: Fixtures.commission),
            sheet: DebugPriceSheets.sheet(for: Fixtures.annual(), commission: Fixtures.commission, canReadSales: true),
            strategy: .recommended,
            showsSuggestions: true
        )
        builder.queuedBasePrice = queuedBase
        return builder
    }

    @Test func withoutAQueuedBaseTodaysBaseCounts() throws {
        let builder = try builder()
        #expect(builder.effectiveBasePrice == builder.sheet.basePrice)
    }

    @Test func aQueuedBaseScalesTheBaseAndEqualizedPrices() throws {
        let today = try builder()
        let raised = try builder(queuedBase: today.sheet.basePrice * 2)
        let brazil = try PricingFixtures.territory("BR")
        let before = try #require(today.input(for: brazil))
        let after = try #require(raised.input(for: brazil))
        #expect(after.basePrice == today.sheet.basePrice * 2)
        #expect(after.equalizedPrice == before.equalizedPrice * 2)
        #expect(after.currentPrice == before.currentPrice)
    }

    @Test func aHigherQueuedBaseMakesTodaysPricesFeelLower() throws {
        let today = try builder()
        let raised = try builder(queuedBase: today.sheet.basePrice * 2)
        let brazil = try PricingFixtures.territory("BR")
        let before = try #require(today.recommendations()[brazil.id])
        let after = try #require(raised.recommendations()[brazil.id])
        #expect(after.ratio < before.ratio)
    }
}
#endif
