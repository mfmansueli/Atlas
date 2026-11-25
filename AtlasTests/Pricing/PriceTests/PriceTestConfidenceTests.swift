//
//  PriceTestConfidenceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A finished price test counts as a measured change: its region's
/// suggestions can be Sure (board 76).
@Suite("PriceConfidenceRule + price tests")
struct PriceTestConfidenceTests {
    private typealias Fixtures = PriceTestFixtures

    private func input(_ evidence: PriceTestEvidence?) -> PriceConfidenceInput {
        var input = PriceConfidenceInput(
            territoryName: "Germany", availability: .available, indexTrust: .exact, indexEditionYear: 2024, hasRealGrid: true,
            signal: nil, pooled: nil, priorChange: nil, asOf: Fixtures.today
        )
        input.priceTest = evidence
        return input
    }

    private func evidence(low: Double, high: Double, beforeStarts: Int = 80, duringStarts: Int = 140) -> PriceTestEvidence {
        PriceTestEvidence(
            region: .europe, endedOn: PricingSampleData.date("2026-11-17"), before: Fixtures.signal(2000, beforeStarts),
            during: Fixtures.signal(2000, duringStarts), points: (low + high) / 2, low: low, high: high
        )
    }

    @Test func aClearTestIsSure() {
        let result = PriceConfidenceRule.evaluate(input(evidence(low: 1.4, high: 4.6)))
        #expect(result.level == .high)
        #expect(result.reason.hasPrefix("Your Europe price test: 80 → 140 starts, 90% range"))
    }

    @Test func aRangeAcrossZeroIsNotSure() {
        #expect(PriceConfidenceRule.evaluate(input(evidence(low: -0.6, high: 2.1))).level != .high)
    }

    @Test func underThirtyStartsOnASideIsNotSure() {
        #expect(PriceConfidenceRule.evaluate(input(evidence(low: 1.4, high: 4.6, beforeStarts: 20))).level != .high)
    }

    @Test func withoutATestNothingChanges() {
        #expect(PriceConfidenceRule.evaluate(input(nil)).level != .high)
    }

    @Test func evidenceComesFromAReadTestOnly() {
        #expect(PriceTestEvidence(Fixtures.test()) == nil)
        var read = Fixtures.test()
        read.windows = PriceTestWindows(
            testBefore: Fixtures.signal(2000, 80, proceeds: 1000), testDuring: Fixtures.signal(2000, 140, proceeds: 1500),
            controlBefore: Fixtures.signal(2000, 80, proceeds: 1000), controlDuring: Fixtures.signal(2000, 80, proceeds: 1000),
            readOn: Fixtures.today
        )
        let evidence = PriceTestEvidence(read)
        #expect(evidence?.region == .europe)
        #expect(evidence?.excludesZero == true)
    }
}
