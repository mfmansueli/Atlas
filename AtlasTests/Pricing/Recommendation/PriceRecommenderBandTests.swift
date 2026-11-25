//
//  PriceRecommenderBandTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The rules that keep today's price when a step wouldn't help (Alba, 25 Nov
/// 2026: 101 suggestions on the real index, 54 of them noise).
@Suite("PriceRecommender band, closer step and floor tolerance")
struct PriceRecommenderBandTests {
    @Test(arguments: [
        (Decimal(115) / 100, true),
        (Decimal(85) / 100, true),
        (Decimal(10) / 10, true),
        (Decimal(116) / 100, false),
        (Decimal(84) / 100, false),
    ])
    func aPriceWithinFifteenPercentMatches(ratio: Decimal, matches: Bool) {
        #expect(PriceRecommender.matchesTarget(ratio: ratio) == matches)
    }

    @Test func aStepThatOvershootsTheTargetDoesNotMoveCloser() {
        // Paraguay: US$ 1.99 felt 1.15×; US$ 1.49 would feel 0.86×.
        #expect(!PriceRecommender.movesCloser(from: Decimal(115) / 100, to: Decimal(86) / 100))
        // Uzbekistan: 1.02× → 1.37×.
        #expect(!PriceRecommender.movesCloser(from: Decimal(102) / 100, to: Decimal(137) / 100))
    }

    @Test func aStepTowardTheTargetMovesCloser() {
        // Singapore: 1.42× → 0.94×.
        #expect(PriceRecommender.movesCloser(from: Decimal(142) / 100, to: Decimal(94) / 100))
        // Twice the target and half of it are as far apart.
        #expect(!PriceRecommender.movesCloser(from: 2, to: Decimal(5) / 10))
    }

    @Test func aPriceAFewCentsUnderTheFloorIsAtTheFloor() {
        // Bhutan: US$ 1.49 against 30% of US$ 4.99 = US$ 1.497.
        #expect(PriceRecommender.isAtFloor(Decimal(149) / 100, floor: Decimal(1497) / 1000))
        #expect(!PriceRecommender.isAtFloor(Decimal(99) / 100, floor: Decimal(1497) / 1000))
    }
}
