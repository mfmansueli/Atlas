//
//  PriceRecommenderConfidenceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// PriceRecommender with HowSure: trust and grid downgrades, the per-state
/// lines, the evidence, and a soft step only as far as the country's own
/// evidence goes. Ecuador (US dollars) at a World Bank level of 0.5 and a
/// $10 base: the target is $5, today's price $7.99.
@Suite("PriceRecommender confidence")
struct PriceRecommenderConfidenceTests {
    private static let asOf = PricingSampleData.date("2026-11-22")

    private func recommender(approximate: Bool = false, asOf: Date = Self.asOf) -> PriceRecommender {
        var snapshot = PricingFixtures.snapshot([.worldBank: ["USA": 1, "ECU": PricingFixtures.money("0.5")]])
        snapshot.isApproximate = approximate
        return PriceRecommender(calculator: PriceCalculator(snapshot: snapshot), asOf: asOf)
    }

    private func ecuador() throws -> PriceCalculationInput {
        try PriceCalculationInput(
            territory: PricingFixtures.territory("EC"),
            basePrice: 10,
            equalizedPrice: 10,
            ladder: PricingFixtures.ladder(["4.99", "5.19", "7.49", "7.99", "9.99"], territoryID: "ECU"),
            currentPrice: PricingFixtures.money("7.99")
        )
    }

    /// 400 page views and 12 trials in 90 days; the base converts at 2%.
    private func evidence(
        availability: PricingSalesData.Availability = .available,
        grid: Bool = true,
        pooled: PooledConversion? = nil,
        recent: SalesSignal? = nil
    ) -> SalesEvidence {
        SalesEvidence(
            canReadSales: availability == .available || availability == .noSalesYet,
            signal: SalesSignal(pageViews: 400, starts: 14, trialStarts: 12, paidStarts: 5),
            baseSignal: SalesSignal(pageViews: 1000, starts: 20, trialStarts: 18),
            availability: availability,
            recentSignal: recent,
            pooled: pooled,
            usesTrials: true,
            hasRealGrid: grid,
            readThrough: Self.asOf
        )
    }

    private func pooled(ownWeight: Double) -> PooledConversion {
        PooledConversion(
            territoryID: "ECU", region: .americas,
            own: SalesSignal(pageViews: 400, starts: 14, trialStarts: 12),
            regionTotal: SalesSignal(pageViews: 3000, starts: 80, trialStarts: 70),
            prior: BetaPrior(mean: 0.03, strength: 400), rate: 0.035, ownWeight: ownWeight
        )
    }

    @Test func realIndexGridAndSalesAreFairlySure() throws {
        let input = try ecuador()
        let recommendation = recommender().recommend(input, evidence: evidence())
        #expect(recommendation.confidence == .medium)
        #expect(recommendation.howSureReason == "\(input.territory.name): 400 page views and 12 trials in 90 days.")
    }

    @Test func aSimulatedGridIsNotVerySure() throws {
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence(grid: false))
        #expect(recommendation.confidence == .low)
        #expect(recommendation.howSureReason == "Apple’s price points for this country aren’t read yet.")
    }

    @Test func approximateIndexDataIsNotVerySure() throws {
        let recommendation = try recommender(approximate: true).recommend(ecuador(), evidence: evidence())
        #expect(recommendation.confidence == .low)
        #expect(recommendation.howSureReason == "Purchasing power here is an estimate, not a published figure.")
    }

    @Test func anEditionOlderThan18MonthsIsNotVerySure() throws {
        // The fixture's edition is Jan 1, 2026: stale after Jul 1, 2027.
        let recommendation = try recommender(asOf: PricingSampleData.date("2027-08-01")).recommend(ecuador(), evidence: evidence())
        #expect(recommendation.confidence == .low)
        #expect(recommendation.howSureReason == "Purchasing power from the 2026 edition, too old to be sure.")
    }

    @Test func noSalesYetSaysSo() throws {
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence(availability: .noSalesYet))
        #expect(recommendation.confidence == .low)
        #expect(recommendation.howSureReason == "Purchasing power only: no sales yet.")
        #expect(recommendation.basis.last == "Sales: none yet, so purchasing power alone")
    }

    @Test func salesTurnedOffSaysSo() throws {
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence(availability: .turnedOff))
        #expect(recommendation.confidence == .low)
        #expect(recommendation.howSureReason == "Purchasing power only: sales data is off in Settings.")
        #expect(recommendation.basis.last == "Sales: off in Settings → Pricing, so purchasing power alone")
        #expect(recommendation.evidence == nil)
    }

    @Test func notReadSalesSaySo() throws {
        let recommendation = try recommender().recommend(ecuador(), evidence: SalesEvidence(canReadSales: false, availability: .notRead))
        #expect(recommendation.basis.last == "Sales: not read yet, so purchasing power alone")
        #expect(recommendation.howSureReason == "Purchasing power only: Atlas hasn’t read your sales yet.")
    }

    @Test func theEvidenceQuotesTheLast28Days() throws {
        let input = try ecuador()
        let recent = SalesSignal(pageViews: 1240, starts: 33, trialStarts: 31, paidStarts: 12)
        let recommendation = recommender().recommend(input, evidence: evidence(recent: recent))
        #expect(recommendation.evidence?.tip == "\(input.territory.name) · 28 days: 1,240 page views, 31 trials, 12 paid")
    }

    @Test func convertingWellWithItsOwnEvidenceHalvesTheStep() throws {
        // 3.5% against the base's 2%: a soft step, at intensity ½.
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence())
        #expect(recommendation.isSoftStep)
        #expect(recommendation.calculation?.multiplier == PricingFixtures.money("0.75"))
    }

    @Test func halfItsOwnEvidenceMovesHalfAsFar() throws {
        // Own weight ½: intensity 1 − ½ × ½ = ¾, × (1 − ¾ + ¾ × 0.5) = 0.625.
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence(pooled: pooled(ownWeight: 0.5)))
        #expect(recommendation.isSoftStep)
        #expect(recommendation.calculation?.multiplier == PricingFixtures.money("0.625"))
    }

    @Test func noOwnEvidenceKeepsThePurchasingPowerTarget() throws {
        let recommendation = try recommender().recommend(ecuador(), evidence: evidence(pooled: pooled(ownWeight: 0)))
        #expect(!recommendation.isSoftStep)
        #expect(recommendation.calculation?.multiplier == PricingFixtures.money("0.5"))
    }
}
