//
//  PriceTestEvaluatorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The verdict against the comparison region (difference in
/// differences), and how sure it is.
@Suite("PriceTestEvaluator")
struct PriceTestEvaluatorTests {
    private typealias Fixtures = PriceTestFixtures

    private func windows(
        during: SalesSignal,
        controlDuring: SalesSignal? = Fixtures.signal(2000, 80, proceeds: 1000),
        before: SalesSignal = Fixtures.signal(2000, 80, proceeds: 1000)
    ) -> PriceTestWindows {
        PriceTestWindows(
            testBefore: before,
            testDuring: during,
            controlBefore: controlDuring == nil ? nil : Fixtures.signal(2000, 80, proceeds: 1000),
            controlDuring: controlDuring,
            readOn: Fixtures.today
        )
    }

    @Test func aClearLiftOverTheComparisonIsBetterAndSure() {
        let result = PriceTestEvaluator.result(windows(during: Fixtures.signal(2000, 140, proceeds: 1500)))
        #expect(result.verdict == .better)
        #expect(result.howSure == .sure)
        #expect(abs(result.points - 3) < 0.001)
        #expect(result.low > 0)
        #expect(result.hasComparison)
    }

    @Test func theSameLiftInTheComparisonIsAboutTheSame() {
        let result = PriceTestEvaluator.result(windows(
            during: Fixtures.signal(2000, 140, proceeds: 1500),
            controlDuring: Fixtures.signal(2000, 140, proceeds: 1500)
        ))
        #expect(result.verdict == .aboutTheSame)
        #expect(abs(result.points) < 0.001)
    }

    @Test func fewerStartsAndLessMoneyIsWorse() {
        let result = PriceTestEvaluator.result(windows(during: Fixtures.signal(2000, 40, proceeds: 600)))
        #expect(result.verdict == .worse)
        #expect(result.high < 0)
    }

    @Test func moreStartsForLessMoneyIsNotBetter() {
        // Conversion up but proceeds down: proceeds hold the verdict back.
        let result = PriceTestEvaluator.result(windows(during: Fixtures.signal(2000, 140, proceeds: 700)))
        #expect(result.verdict == .aboutTheSame)
    }

    @Test func underThirtyStartsOnASideIsTooFewToTell() {
        let result = PriceTestEvaluator.result(windows(during: Fixtures.signal(2000, 140), before: Fixtures.signal(400, 12)))
        #expect(result.verdict == .tooLittleData)
        #expect(result.howSure == nil)
    }

    @Test func withoutAComparisonItsNeverSure() {
        let result = PriceTestEvaluator.result(windows(during: Fixtures.signal(2000, 140, proceeds: 1500), controlDuring: nil))
        #expect(result.verdict == .better)
        #expect(result.howSure == .fairlySure)
        #expect(!result.hasComparison)
    }

    @Test func aRunningTestHasNoResultUntilItsDaysAreRead() {
        let running = Fixtures.test()
        #expect(running.phase(on: Fixtures.today) == .running(day: 9))
        let over = PricingSampleData.date("2026-12-20")
        #expect(running.phase(on: over) == .waitingForResult)
        var read = running
        read.windows = windows(during: Fixtures.signal(2000, 140, proceeds: 1500))
        #expect(read.result?.verdict == .better)
        #expect(read.endsOn == PricingSampleData.date("2026-12-15"))
        #expect(read.returnDay == "2026-12-15")
    }
}
