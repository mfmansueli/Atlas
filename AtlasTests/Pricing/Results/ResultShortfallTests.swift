//
//  ResultShortfallTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 76: "Too few to tell" says which threshold isn't met, with the
/// count, naming the one furthest from met.
@Suite("ResultShortfall")
struct ResultShortfallTests {
    private func window(starts: Int, views: Int, days: Int = ResultsEvaluator.windowDays) -> SalesWindow {
        SalesWindow(pageViews: views, starts: starts, proceeds: 100, days: days)
    }

    @Test func tooFewStartsNamesTheShorterSide() {
        let shortfall = ResultShortfall.of(before: window(starts: 12, views: 380), after: window(starts: 14, views: 391))
        #expect(shortfall == .starts(12))
        #expect(shortfall?.text == "12 starts · needs 30")
    }

    @Test func tooFewPageViews() {
        let shortfall = ResultShortfall.of(before: window(starts: 31, views: 64), after: window(starts: 33, views: 70))
        #expect(shortfall == .pageViews(64))
        #expect(shortfall?.text == "64 page views · needs 100")
    }

    @Test func tooFewDays() {
        let shortfall = ResultShortfall.of(before: window(starts: 90, views: 3000), after: window(starts: 90, views: 3000, days: 21))
        #expect(shortfall == .days(21))
        #expect(shortfall?.text == "21 days · needs 28")
    }

    @Test func bothShortNamesTheOneFurthestFromItsThreshold() {
        // 25 of 30 starts (83%) against 40 of 100 page views (40%).
        #expect(ResultShortfall.of(before: window(starts: 25, views: 40), after: window(starts: 40, views: 200)) == .pageViews(40))
        // 6 of 30 starts (20%) against 90 of 100 page views (90%).
        #expect(ResultShortfall.of(before: window(starts: 6, views: 90), after: window(starts: 40, views: 200)) == .starts(6))
    }

    @Test func aTieNamesStarts() {
        // 15 of 30 starts and 50 of 100 page views: half of each.
        #expect(ResultShortfall.of(before: window(starts: 15, views: 50), after: window(starts: 40, views: 200)) == .starts(15))
    }

    @Test func moreStartsThanPageViews() {
        let shortfall = ResultShortfall.of(before: window(starts: 140, views: 120), after: window(starts: 60, views: 3000))
        #expect(shortfall == .startsOutsidePage)
        #expect(shortfall?.text == "More starts than page views")
    }

    @Test func enoughOfEverythingIsNoShortfall() {
        #expect(ResultShortfall.of(before: window(starts: 31, views: 4800), after: window(starts: 68, views: 4950)) == nil)
    }

    @Test func oneSaysItInTheSingular() {
        #expect(ResultShortfall.starts(1).text == "1 start · needs 30")
        #expect(ResultShortfall.pageViews(1).text == "1 page view · needs 100")
        #expect(ResultShortfall.days(1).text == "1 day · needs 28")
        #expect(ResultShortfall.starts(0).text == "0 starts · needs 30")
    }

    @Test func onlyTooFewToTellHasAShortfall() throws {
        let territory = try PricingFixtures.territory("PT")
        var result = PriceChangeResult(
            territory: territory, oldPrice: 39.99, newPrice: 29.99,
            before: window(starts: 5, views: 380), after: window(starts: 7, views: 391)
        )
        #expect(result.verdict == .tooLittleData)
        #expect(result.shortfall == .starts(5))
        result.before = window(starts: 31, views: 4800)
        result.after = window(starts: 68, views: 4950)
        #expect(result.verdict != .tooLittleData)
        #expect(result.shortfall == nil)
    }

    @Test func everyShortfallIsAVerdictOfTooFew() {
        // Whatever a shortfall names, the evaluator agrees there's no verdict.
        let pairs = [
            (window(starts: 12, views: 380), window(starts: 14, views: 391)),
            (window(starts: 31, views: 64), window(starts: 33, views: 70)),
            (window(starts: 90, views: 3000), window(starts: 90, views: 3000, days: 21)),
            (window(starts: 140, views: 120), window(starts: 60, views: 3000)),
        ]
        for (before, after) in pairs {
            #expect(ResultShortfall.of(before: before, after: after) != nil)
            #expect(ResultsEvaluator.verdict(before: before, after: after) == .tooLittleData)
        }
    }
}
