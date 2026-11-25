//
//  PriceConfidenceRuleTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// HowSure's levels at and around each limit, and their reasons.
@Suite("PriceConfidenceRule")
struct PriceConfidenceRuleTests {
    private static let asOf = PricingSampleData.date("2026-11-22")
    private static let may = PricingSampleData.date("2026-05-12")

    private func input(
        availability: PricingSalesData.Availability = .available,
        trust: PriceIndexTrust = .exact,
        year: Int? = 2024,
        grid: Bool = true,
        signal: SalesSignal? = nil,
        pooled: PooledConversion? = nil,
        prior: PriorPriceChange? = nil,
        usesTrials: Bool = true,
        asOf: Date = Self.asOf
    ) -> PriceConfidenceInput {
        PriceConfidenceInput(
            territoryName: "Brazil", availability: availability, indexTrust: trust, indexEditionYear: year, hasRealGrid: grid,
            signal: signal, pooled: pooled, priorChange: prior, usesTrials: usesTrials, asOf: asOf
        )
    }

    private func sample(_ pageViews: Int, trials: Int) -> SalesSignal {
        SalesSignal(pageViews: pageViews, starts: trials, trialStarts: trials)
    }

    private func pooledEurope(own: SalesSignal, region: SalesSignal) -> PooledConversion {
        PooledConversion(
            territoryID: "PRT", region: .europe, own: own, regionTotal: region,
            prior: BetaPrior(mean: 0.01, strength: 100), rate: 0.01, ownWeight: 0.3
        )
    }

    private func change(before: SalesSignal, after: SalesSignal, on date: Date = Self.may) -> PriorPriceChange {
        PriorPriceChange(date: date, previousPrice: 249, before: before, after: after)
    }

    private let lift = (before: SalesSignal(pageViews: 2000, starts: 41), after: SalesSignal(pageViews: 2100, starts: 70))

    // MARK: - Not very sure

    @Test(arguments: [
        (PricingSalesData.Availability.noSalesYet, "Purchasing power only: no sales yet."),
        (.roleCannotRead, "Purchasing power only: this key’s role can’t read sales."),
        (.turnedOff, "Purchasing power only: sales data is off in Settings."),
        (.notRead, "Purchasing power only: Atlas hasn’t read your sales yet."),
    ])
    func salesThatDontCountArePurchasingPowerOnly(availability: PricingSalesData.Availability, reason: String) {
        let result = PriceConfidenceRule.evaluate(input(availability: availability, signal: sample(5000, trials: 100)))
        #expect(result.level == .low)
        #expect(result.reason == reason)
    }

    @Test func anEstimatedIndexValueIsNotVerySure() {
        let result = PriceConfidenceRule.evaluate(input(trust: .approximate, signal: sample(5000, trials: 100)))
        #expect(result.level == .low)
        #expect(result.reason == "Purchasing power here is an estimate, not a published figure.")
    }

    @Test func aStaleEditionIsNotVerySure() {
        let result = PriceConfidenceRule.evaluate(input(trust: .stale, year: 2023, signal: sample(5000, trials: 100)))
        #expect(result.level == .low)
        #expect(result.reason == "Purchasing power from the 2023 edition, too old to be sure.")
        #expect(PriceConfidenceRule.evaluate(input(trust: .stale, year: nil)).reason == "Purchasing power from an index edition over 18 months old.")
    }

    @Test func aMissingIndexValueIsNotVerySure() {
        let result = PriceConfidenceRule.evaluate(input(trust: .missing, signal: sample(5000, trials: 100)))
        #expect(result.level == .low)
        #expect(result.reason == "No purchasing power figure for this country.")
    }

    @Test func aFallbackValueCountsAsReal() {
        #expect(PriceConfidenceRule.evaluate(input(trust: .fallback, signal: sample(300, trials: 10))).level == .medium)
    }

    @Test func aSimulatedGridIsNotVerySure() {
        let prior = change(before: lift.before, after: lift.after)
        let result = PriceConfidenceRule.evaluate(input(grid: false, signal: sample(5000, trials: 100), prior: prior))
        #expect(result.level == .low)
        #expect(result.reason == "Apple’s price points for this country aren’t read yet.")
    }

    @Test func noPageViewsIsPurchasingPowerOnly() {
        #expect(PriceConfidenceRule.evaluate(input()).reason == "Purchasing power only: no page views here in 90 days.")
    }

    // MARK: - Fairly sure

    @Test func threeHundredPageViewsAndTenTrialsAreFairlySure() {
        let result = PriceConfidenceRule.evaluate(input(signal: sample(300, trials: 10)))
        #expect(result.level == .medium)
        #expect(result.reason == "Brazil: 300 page views and 10 trials in 90 days.")
        #expect(result.borrowedFrom == nil)
    }

    @Test func twoHundredNinetyNinePageViewsAreTooFew() {
        let result = PriceConfidenceRule.evaluate(input(signal: sample(299, trials: 10)))
        #expect(result.level == .low)
        #expect(result.reason == "Too few yet: 299 page views and 10 trials in 90 days.")
    }

    @Test func nineTrialsAreTooFew() {
        let result = PriceConfidenceRule.evaluate(input(signal: sample(300, trials: 9)))
        #expect(result.level == .low)
        #expect(result.reason == "Too few yet: 300 page views and 9 trials in 90 days.")
    }

    @Test func withoutTrialsEveryStartCounts() {
        let signal = SalesSignal(pageViews: 1240, starts: 12)
        let result = PriceConfidenceRule.evaluate(input(signal: signal, usesTrials: false))
        #expect(result.level == .medium)
        #expect(result.reason == "Brazil: 1,240 page views and 12 starts in 90 days.")
        #expect(PriceConfidenceRule.evaluate(input(signal: signal, usesTrials: true)).level == .low)
    }

    @Test func aThinCountryBorrowsItsRegionsSample() {
        let own = sample(40, trials: 1)
        let result = PriceConfidenceRule.evaluate(input(signal: own, pooled: pooledEurope(own: own, region: sample(2100, trials: 24))))
        #expect(result.level == .medium)
        #expect(result.reason == "Europe: 2,100 page views and 24 trials in 90 days.")
        #expect(result.borrowedFrom == .europe)
    }

    @Test func aThinRegionIsNotEnough() {
        let own = sample(40, trials: 1)
        let result = PriceConfidenceRule.evaluate(input(signal: own, pooled: pooledEurope(own: own, region: sample(299, trials: 24))))
        #expect(result.level == .low)
        #expect(result.reason == "Too few yet: 40 page views and 1 trial in 90 days.")
    }

    @Test func aCountryWithoutPageViewsDoesntBorrow() {
        let result = PriceConfidenceRule.evaluate(input(signal: nil, pooled: pooledEurope(own: .zero, region: sample(2100, trials: 24))))
        #expect(result.level == .low)
    }

    // MARK: - Sure

    @Test func aClearEarlierChangeIsSure() {
        let result = PriceConfidenceRule.evaluate(input(signal: sample(300, trials: 10), prior: change(before: lift.before, after: lift.after)))
        #expect(result.level == .high)
        #expect(result.reason == "Your May change: 41 → 70 starts, 90% range +0.5 to +2.1 points.")
        #expect(result.effect?.excludesZero == true)
    }

    @Test func sureNeedsNoSampleOfItsOwn() {
        #expect(PriceConfidenceRule.evaluate(input(prior: change(before: lift.before, after: lift.after))).level == .high)
    }

    @Test func twentyNineStartsOnASideAreNotSure() {
        let before = SalesSignal(pageViews: 2000, starts: 29)
        let prior = change(before: before, after: SalesSignal(pageViews: 2100, starts: 70))
        #expect(PriceConfidenceRule.evaluate(input(prior: prior)).level == .low)
        #expect(PriceConfidenceRule.evaluate(input(signal: sample(300, trials: 10), prior: prior)).level == .medium)
        let thirty = change(before: SalesSignal(pageViews: 2000, starts: 30), after: SalesSignal(pageViews: 2100, starts: 70))
        #expect(PriceConfidenceRule.evaluate(input(prior: thirty)).level == .high)
    }

    @Test func twentySevenDaysAfterAreNotSure() {
        let recent = PricingSampleData.date("2026-10-26")
        let prior = change(before: lift.before, after: lift.after, on: recent)
        #expect(PriceConfidenceRule.evaluate(input(prior: prior, asOf: PricingSampleData.date("2026-11-22"))).level == .low)
        #expect(PriceConfidenceRule.evaluate(input(prior: prior, asOf: PricingSampleData.date("2026-11-23"))).level == .high)
    }

    @Test func aRangeThatIncludesZeroIsNotSure() {
        let prior = change(before: SalesSignal(pageViews: 1000, starts: 30), after: SalesSignal(pageViews: 1000, starts: 32))
        let result = PriceConfidenceRule.evaluate(input(signal: sample(300, trials: 10), prior: prior))
        #expect(result.level == .medium)
        #expect(result.effect == nil)
    }
}
