//
//  FunnelStepSummaryTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("Analytics · the Overview's funnel cards")
struct FunnelStepSummaryTests {
    private func measured(_ count: Int, of total: Int) -> AnalyticsRate {
        let value = Double(count) / Double(total)
        return .measured(MeasuredRate(count: count, total: total, value: value, low: value * 0.9, high: value * 1.1, bars: 3))
    }

    @Test func aStepSaysItsShareInWordsWithTheVerdictAndPoints() {
        var step = FunnelStep(stage: .pageViews, count: 9870, rate: measured(9870, of: 182_800))
        step.comparison = PeriodComparison(outcome: .lower(.sure), points: -0.4, zScore: -4)
        let summary = FunnelStepSummary.make(step, isNew: false)
        let percent = AnalyticsText.percent(9870.0 / 182_800.0)
        #expect(summary.sentence == "\(percent) of impressions opened the page")
        #expect(summary.verdict == .worse)
        #expect(summary.points == AnalyticsText.points(-0.4))
        #expect(summary.howSure == .sure)
        #expect(summary.tooltip.contains("How sure: Sure"))
        #expect(summary.accessibilityText.contains("Product page views"))
        #expect(summary.accessibilityText.contains("Worse"))
    }

    @Test func eachStepHasItsOwnSentence() {
        #expect(FunnelStepSummary.sentence(.downloads, share: "x") == "x of page views downloaded")
        #expect(FunnelStepSummary.sentence(.trials, share: "x") == "x of downloads started a trial")
        #expect(FunnelStepSummary.sentence(.paid, share: "x") == "x of trials paid")
        #expect(FunnelStepSummary.sentence(.impressions, share: "x") == nil)
    }

    @Test func aDifferenceThatCouldBeChanceIsAboutTheSameAndNotVerySure() {
        var step = FunnelStep(stage: .downloads, count: 400, rate: measured(400, of: 9000))
        step.comparison = PeriodComparison(outcome: .same, points: 0.1, zScore: 0.3)
        let summary = FunnelStepSummary.make(step, isNew: false)
        #expect(summary.verdict == .same)
        #expect(summary.verdict?.title == "About the same")
        #expect(summary.howSure == .notVerySure)
        var better = step
        better.comparison = PeriodComparison(outcome: .higher(.fairlySure), points: 0.6, zScore: 2)
        #expect(FunnelStepSummary.make(better, isNew: false).verdict == .better)
        #expect(FunnelStepSummary.make(better, isNew: false).howSure == .fairlySure)
    }

    @Test func tooFewShowsCountsInsteadOfARate() {
        let step = FunnelStep(stage: .trials, count: 3, rate: .tooFew(count: 3, total: 40))
        let summary = FunnelStepSummary.make(step, isNew: false)
        #expect(summary.sentence == "3 of 40 downloads started a trial")
        #expect(summary.plainWord == "Too few to tell")
        #expect(summary.verdict == nil)
        #expect(summary.howSure == nil)
    }

    @Test func aMissingStepSaysWhy() {
        let step = FunnelStep(stage: .paid, count: nil, gap: .needsVendorNumber, rate: .missing)
        let summary = FunnelStepSummary.make(step, isNew: false)
        #expect(summary.count == "—")
        #expect(summary.isGap)
        #expect(summary.sentence == FunnelGap.needsVendorNumber.text)
    }

    @Test func theFirstStepComparesItsCountAndANewAppHasNoVerdict() {
        var first = FunnelStep(stage: .impressions, count: 182_800, rate: .missing)
        first.change = "+7%"
        #expect(FunnelStepSummary.make(first, isNew: false).sentence == "+7% vs before")
        let step = FunnelStep(stage: .pageViews, count: 500, rate: measured(500, of: 9000))
        let new = FunnelStepSummary.make(step, isNew: true)
        #expect(new.verdict == nil)
        #expect(new.plainWord == "No earlier period yet")
    }
}
