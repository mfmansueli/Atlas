//
//  PriorChangeEffectTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The 90% range of an earlier change's effect on conversion.
@Suite("PriorChangeEffect")
struct PriorChangeEffectTests {
    @Test func aClearLiftExcludesZero() throws {
        let effect = try #require(PriorChangeEffect(before: SalesSignal(pageViews: 1000, starts: 30), after: SalesSignal(pageViews: 1000, starts: 60)))
        #expect(abs(effect.points - 3) < 1e-9)
        #expect(abs(effect.low - 1.483) < 0.01)
        #expect(abs(effect.high - 4.560) < 0.01)
        #expect(effect.excludesZero)
    }

    @Test func aSmallChangeIncludesZero() throws {
        let effect = try #require(PriorChangeEffect(before: SalesSignal(pageViews: 1000, starts: 30), after: SalesSignal(pageViews: 1000, starts: 32)))
        #expect(effect.low < 0)
        #expect(effect.high > 0)
        #expect(!effect.excludesZero)
    }

    @Test func aClearDropExcludesZeroToo() throws {
        let effect = try #require(PriorChangeEffect(before: SalesSignal(pageViews: 1000, starts: 60), after: SalesSignal(pageViews: 1000, starts: 30)))
        #expect(effect.high < 0)
        #expect(effect.excludesZero)
    }

    @Test func aRangeTouchingZeroDoesntExcludeIt() {
        let before = SalesSignal(pageViews: 1000, starts: 30)
        #expect(!PriorChangeEffect(before: before, after: before, points: 1, low: 0, high: 2).excludesZero)
        #expect(!PriorChangeEffect(before: before, after: before, points: -1, low: -2, high: 0).excludesZero)
        #expect(PriorChangeEffect(before: before, after: before, points: 1, low: 0.01, high: 2).excludesZero)
    }

    @Test func noPageViewsNoEffect() {
        #expect(PriorChangeEffect(before: .zero, after: SalesSignal(pageViews: 10, starts: 1)) == nil)
    }

    @Test func pointsAreSignedToOneDecimal() {
        #expect(PriceConfidenceText.points(1.25) == "+1.3")
        #expect(PriceConfidenceText.points(-0.44) == "−0.4")
        #expect(PriceConfidenceText.points(0.01) == "0.0")
        #expect(PriceConfidenceText.month(PricingSampleData.date("2026-05-12")) == "May")
    }
}
