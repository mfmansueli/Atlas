//
//  BetaPriorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Beta-Binomial updates and the method-of-moments prior.
@Suite("BetaPrior")
struct BetaPriorTests {
    private static let minimum = ConversionPooling.minimumStrength
    private static let maximum = ConversionPooling.maximumStrength

    private func prior(_ samples: [SalesSignal]) -> BetaPrior? {
        BetaPrior.methodOfMoments(samples, minimumStrength: Self.minimum, maximumStrength: Self.maximum)
    }

    @Test func posteriorAddsTheSampleToThePrior() {
        // Beta(2, 98) and 10 of 400: (10 + 2) ÷ (400 + 100).
        let prior = BetaPrior(mean: 0.02, strength: 100)
        #expect(abs(prior.alpha - 2) < 1e-12)
        #expect(abs(prior.beta - 98) < 1e-12)
        #expect(abs(prior.posteriorMean(starts: 10, pageViews: 400) - 0.024) < 1e-12)
        #expect(abs(prior.ownWeight(pageViews: 400) - 0.8) < 1e-12)
    }

    @Test func withoutASampleThePosteriorIsThePrior() {
        let prior = BetaPrior(mean: 0.03, strength: 250)
        #expect(abs(prior.posteriorMean(starts: 0, pageViews: 0) - 0.03) < 1e-12)
        #expect(prior.ownWeight(pageViews: 0) == 0)
    }

    @Test func startsNeverExceedPageViews() {
        let prior = BetaPrior(mean: 0.5, strength: 2)
        #expect(prior.posteriorMean(starts: 50, pageViews: 10) <= 1)
    }

    @Test func methodOfMomentsSubtractsBinomialNoise() throws {
        // 1% and 3% on 1,000 page views each: m = 2%, s² = 1e-4,
        // noise = 0.0196 × 2 ÷ 2,000, M = 0.0196 ÷ 8.04e-5 − 1.
        let prior = try #require(prior([SalesSignal(pageViews: 1000, starts: 10), SalesSignal(pageViews: 1000, starts: 30)]))
        #expect(abs(prior.mean - 0.02) < 1e-12)
        #expect(abs(prior.strength - 242.781) < 0.01)
    }

    @Test func countriesThatLookAlikeGetTheMaximumStrength() throws {
        let prior = try #require(prior([SalesSignal(pageViews: 1000, starts: 20), SalesSignal(pageViews: 2000, starts: 40)]))
        #expect(prior.strength == Self.maximum)
        #expect(abs(prior.mean - 0.02) < 1e-12)
    }

    @Test func oneCountryOrNoStartsGetTheMinimumStrength() throws {
        let one = try #require(prior([SalesSignal(pageViews: 500, starts: 10)]))
        #expect(one.strength == Self.minimum)
        #expect(abs(one.mean - 0.02) < 1e-12)
        let none = try #require(prior([SalesSignal(pageViews: 500, starts: 0), SalesSignal(pageViews: 300, starts: 0)]))
        #expect(none.strength == Self.minimum)
        #expect(none.mean == 0)
    }

    @Test func aWideSpreadStopsAtTheMinimumStrength() throws {
        // 0% and 50%: the spread is huge, so M would be under 1.
        let prior = try #require(prior([SalesSignal(pageViews: 1000, starts: 0), SalesSignal(pageViews: 1000, starts: 500)]))
        #expect(prior.strength == Self.minimum)
    }

    @Test func noPageViewsNoPrior() {
        #expect(prior([]) == nil)
        #expect(prior([SalesSignal(pageViews: 0, starts: 0)]) == nil)
    }
}
