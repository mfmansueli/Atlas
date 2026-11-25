//
//  PriceLevelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Design system: price level and change pill")
struct PriceLevelTests {
    @Test func theBoundsPickTheStep() {
        #expect(PriceLevel(ratio: 0.5) == .muchCheaper)
        #expect(PriceLevel(ratio: 0.7) == .cheaper)
        #expect(PriceLevel(ratio: 0.9) == .aboutTheSame)
        #expect(PriceLevel(ratio: 1.15) == .pricier)
        #expect(PriceLevel(ratio: 1.6) == .muchPricier)
        #expect(PriceLevel.allCases.count == 5)
    }

    @Test func confidenceReadsInTheHousesWords() {
        #expect(RecommendationConfidence.low.howSure == .notVerySure)
        #expect(RecommendationConfidence.medium.howSure == .fairlySure)
        #expect(RecommendationConfidence.high.howSure == .sure)
    }

    @Test func increasesAreAmberAndDecreasesGrey() {
        #expect(PriceChange(old: 10, new: 12).pillTint == Palette.warn)
        #expect(PriceChange(old: 12, new: 10).pillTint == Palette.label2)
    }
}
#endif
