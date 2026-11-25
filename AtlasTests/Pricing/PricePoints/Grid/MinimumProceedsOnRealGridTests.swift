//
//  MinimumProceedsOnRealGridTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The minimum proceeds limit on Apple's own points: the cheapest point
/// whose proceeds (Apple's, after tax and commission) reach it, instead of
/// a price worked out from the tax rate.
@Suite("Pricing · minimum proceeds from Apple's points")
struct MinimumProceedsOnRealGridTests {
    /// Points whose proceeds Apple rounds its own way: not price ÷ tax × 0.85.
    private static let ladder = PricePointLadder(territoryID: "BRA", currencyCode: "BRL", points: [
        PricePoint(customerPrice: PricingFixtures.money("9.90"), proceeds: PricingFixtures.money("6.50")),
        PricePoint(customerPrice: PricingFixtures.money("12.90"), proceeds: PricingFixtures.money("8.40")),
        PricePoint(customerPrice: PricingFixtures.money("14.90"), proceeds: PricingFixtures.money("9.80")),
        PricePoint(customerPrice: PricingFixtures.money("19.90"), proceeds: PricingFixtures.money("13.10")),
    ])

    private func input(real: Bool) throws -> PriceCalculationInput {
        var input = try PricingFixtures.annualInput("BRA")
        input.ladder = Self.ladder
        input.hasRealLadder = real
        return input
    }

    @Test func theCheapestPointThatEarnsEnough() {
        #expect(Self.ladder.lowest(withProceedsAtLeast: PricingFixtures.money("8.40"))?.customerPrice == PricingFixtures.money("12.90"))
        #expect(Self.ladder.lowest(withProceedsAtLeast: PricingFixtures.money("8.41"))?.customerPrice == PricingFixtures.money("14.90"))
        #expect(Self.ladder.lowest(withProceedsAtLeast: PricingFixtures.money("20")) == nil)
    }

    @Test func aRealLadderUsesApplesProceeds() throws {
        let calculator = PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: .smallBusiness)
        let minimum = try calculator.minimumPrice(forProceeds: PricingFixtures.money("9"), input: input(real: true))
        #expect(minimum == PricingFixtures.money("14.90"))
    }

    @Test func aSimulatedLadderWorksItOutFromTheTaxRate() throws {
        let calculator = PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: .smallBusiness)
        let input = try input(real: false)
        let minimum = calculator.minimumPrice(forProceeds: PricingFixtures.money("9"), input: input)
        #expect(minimum == Commission.smallBusiness.customerPrice(forProceeds: PricingFixtures.money("9"), taxRate: input.territory.taxRate))
    }

    @Test func aRealLadderWithoutAnyPointThatEarnsEnoughFallsBack() throws {
        let calculator = PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: .standard)
        let input = try input(real: true)
        let minimum = calculator.minimumPrice(forProceeds: PricingFixtures.money("50"), input: input)
        #expect(minimum == Commission.standard.customerPrice(forProceeds: PricingFixtures.money("50"), taxRate: input.territory.taxRate))
    }
}
