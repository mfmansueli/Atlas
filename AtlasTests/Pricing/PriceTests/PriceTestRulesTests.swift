//
//  PriceTestRulesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 76's sample gate, one test per region and the comparison.
@Suite("PriceTestRules")
struct PriceTestRulesTests {
    private typealias Fixtures = PriceTestFixtures

    @Test func underThirtyStartsIsRefusedWithABiggerRegion() throws {
        let refusal = try #require(PriceTestRules.refusal(region: .africaMiddleEast, sample: Fixtures.signal(400, 12), step: .percent(-20)))
        #expect(refusal == "Too few people to tell: Africa & Middle East had 12 starts in 28 days, and a test needs 30. Try a bigger region.")
    }

    @Test func underAHundredPageViewsIsRefused() throws {
        let refusal = try #require(PriceTestRules.refusal(region: .europe, sample: Fixtures.signal(90, 40), step: .percent(-20)))
        #expect(refusal.contains("90 page views in 28 days, and a test needs 100."))
    }

    @Test func suggestedPricesTryAPercentage() throws {
        let refusal = try #require(PriceTestRules.refusal(region: .asiaPacific, sample: Fixtures.signal(400, 12), step: .suggested))
        #expect(refusal.hasSuffix("Try a percentage for the whole region."))
    }

    @Test func enoughPeopleIsNotRefused() {
        #expect(PriceTestRules.refusal(region: .europe, sample: Fixtures.signal(2140, 96), step: .percent(-20)) == nil)
        #expect(PriceTestRules.refusal(region: .europe, sample: Fixtures.signal(100, 30), step: .percent(-20)) == nil)
    }

    @Test func oneTestPerRegionAtATime() {
        let running = Fixtures.test(region: .europe)
        #expect(PriceTestRules.conflict(in: .europe, tests: [running], on: Fixtures.today)?.id == running.id)
        #expect(PriceTestRules.conflict(in: .asiaPacific, tests: [running], on: Fixtures.today) == nil)
    }

    @Test func aQueuedTestHoldsItsRegionToo() {
        let queued = Fixtures.test(state: .queued, startedOn: nil)
        #expect(PriceTestRules.regionsUnderTest([queued], on: Fixtures.today) == [.europe])
    }

    @Test func aFinishedTestFreesItsRegion() {
        let finished = Fixtures.test(startedOn: PricingSampleData.date("2026-10-01"))
        let ended = Fixtures.test(state: .endedEarly)
        #expect(PriceTestRules.regionsUnderTest([finished, ended], on: Fixtures.today).isEmpty)
    }

    @Test func automaticPicksTheMostSimilarTraffic() {
        let samples: [TerritoryRegion: SalesSignal] = [
            .europe: Fixtures.signal(2140, 96),
            .asiaPacific: Fixtures.signal(2200, 88),
            .americas: Fixtures.signal(2600, 88),
            .africaMiddleEast: Fixtures.signal(2150, 12),
        ]
        // Africa & Middle East is closest in page views but has 12 starts.
        #expect(PriceTestRules.automaticControl(for: .europe, samples: samples, underTest: []) == .asiaPacific)
        #expect(PriceTestRules.automaticControl(for: .europe, samples: samples, underTest: [.asiaPacific]) == .americas)
    }

    @Test func aRegionUnderTestCantBeTheComparison() {
        #expect(!PriceTestRules.canCompare(.asiaPacific, with: .europe, sample: Fixtures.signal(2200, 88), underTest: [.asiaPacific]))
        #expect(!PriceTestRules.canCompare(.europe, with: .europe, sample: Fixtures.signal(2200, 88), underTest: []))
        #expect(PriceTestRules.canCompare(.asiaPacific, with: .europe, sample: Fixtures.signal(2200, 88), underTest: []))
    }
}
