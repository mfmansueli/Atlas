//
//  ResultsEvaluatorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("ResultsEvaluator")
struct ResultsEvaluatorTests {
    private func window(_ starts: Int, _ proceeds: Decimal, views: Int = 1000) -> SalesWindow {
        SalesWindow(pageViews: views, starts: starts, proceeds: proceeds)
    }

    // MARK: - Verdicts

    @Test func conversionUpAndProceedsNoLowerIsBetter() {
        #expect(ResultsEvaluator.verdict(before: window(31, 1053, views: 4800), after: window(68, 1155, views: 4950)) == .better)
        #expect(ResultsEvaluator.verdict(before: window(31, 1053, views: 4800), after: window(68, 1053, views: 4950)) == .better)
    }

    @Test func conversionUpForLessProceedsIsAboutTheSame() {
        let verdict = ResultsEvaluator.verdict(before: window(31, 1053, views: 4800), after: window(68, 1000, views: 4950))
        #expect(verdict == .aboutTheSame)
        #expect(!verdict.offersRestore)
        #expect(verdict.title == "About the same")
    }

    @Test func conversionDownAndProceedsNoHigherIsWorseAndOffersRestore() {
        let verdict = ResultsEvaluator.verdict(before: window(90, 1144, views: 3000), after: window(55, 702, views: 3100))
        #expect(verdict == .worse)
        #expect(verdict.offersRestore)
        #expect(ResultsEvaluator.verdict(before: window(90, 1144, views: 3000), after: window(55, 1300, views: 3100)) == .aboutTheSame)
    }

    @Test func aDifferenceTheIntervalCantTellFromChanceIsAboutTheSame() {
        let verdict = ResultsEvaluator.verdict(before: window(92, 2986, views: 4600), after: window(98, 2704, views: 4740))
        #expect(verdict == .aboutTheSame)
        let change = ResultsEvaluator.conversionChange(before: window(92, 2986, views: 4600), after: window(98, 2704, views: 4740))
        #expect(change.outcome == .same)
    }

    @Test func under30StartsOr28DaysOnASideIsTooFewToTell() {
        #expect(ResultsEvaluator.verdict(before: window(29, 10, views: 3000), after: window(90, 900, views: 3000)) == .tooLittleData)
        #expect(ResultsEvaluator.verdict(before: window(90, 10, views: 3000), after: window(29, 9, views: 3000)) == .tooLittleData)
        var short = window(90, 900, views: 3000)
        short.days = 27
        #expect(ResultsEvaluator.verdict(before: window(30, 100, views: 3000), after: short) == .tooLittleData)
        #expect(!ResultVerdict.tooLittleData.hasEnoughData)
        #expect(ResultVerdict.tooLittleData.title == "Too few to tell")
    }

    @Test func fewPageViewsOrMoreStartsThanViewsIsTooFewToTell() {
        // Under Analytics' 100 page views a side.
        #expect(ResultsEvaluator.verdict(before: window(30, 100, views: 90), after: window(60, 200, views: 95)) == .tooLittleData)
        // Starts from outside the page (offer codes) make the rate meaningless.
        #expect(ResultsEvaluator.verdict(before: window(40, 100, views: 30), after: window(60, 200, views: 3000)) == .tooLittleData)
    }

    @Test func windowsFromSignalsKeepTheirDays() {
        let window = SalesWindow(signal: SalesSignal(pageViews: 300, starts: 12, proceeds: 40), days: 11)
        #expect(window.pageViews == 300)
        #expect(window.starts == 12)
        #expect(window.proceeds == 40)
        #expect(window.days == 11)
        #expect(SalesWindow(pageViews: 1, starts: 0, proceeds: 0).days == ResultsEvaluator.windowDays)
    }

    // MARK: - Availability

    @Test func tooEarlyUntilDay28() {
        let push = PricingSampleData.pushDate
        let arrives = PricingSampleData.date("2026-11-23")
        #expect(ResultsEvaluator.availability(changedOn: push, now: push) == .tooEarly(day: 1, arrivesOn: arrives))
        let dayTen = PricingSampleData.date("2026-11-04")
        #expect(ResultsEvaluator.availability(changedOn: push, now: dayTen) == .tooEarly(day: 10, arrivesOn: arrives))
        #expect(ResultsEvaluator.availability(changedOn: push, now: PricingSampleData.date("2026-11-22")) == .tooEarly(day: 28, arrivesOn: arrives))
        #expect(ResultsEvaluator.availability(changedOn: push, now: arrives) == .ready)
        #expect(PricingText.date(arrives) == "Nov 23, 2026")
    }

    // MARK: - Summary

    @Test func summaryCountsOnlyTerritoriesWithEnoughData() {
        let brazil = PriceChangeResult(
            territory: Territory(id: "BRA", alpha2: "BR", name: "Brazil", region: .americas, currencyCode: "BRL", taxRate: 0, latitude: 0, longitude: 0),
            oldPrice: PricingFixtures.money("219.9"),
            newPrice: PricingFixtures.money("109.9"),
            before: window(31, 1000),
            after: window(68, 1100)
        )
        var quiet = brazil
        quiet.before = window(2, 50)
        quiet.after = window(3, 40)
        let summary = ResultsEvaluator.summarize([brazil, quiet])
        #expect(summary.territoryCount == 2)
        #expect(summary.countedCount == 1)
        #expect(summary.tooLittleDataCount == 1)
        #expect(summary.startsBefore == 31)
        #expect(summary.startsAfter == 68)
        #expect(summary.startsChange.percentText == "+119%")
        #expect(summary.proceedsChange.percentText == "+10%")
        #expect(summary.breakdownText == "1 better · 0 worse · 1 too few sales to tell")
        #expect(brazil.startsChange?.percentText == "+119%")
        #expect(brazil.priceChange.percentText == "−50%")
    }

    @Test func sampleResultsCountOnlyTerritoriesWithThirtyStartsEachSide() {
        let results = PricingFixtures.sample.results()
        let summary = ResultsEvaluator.summarize(results)
        #expect(summary.territoryCount == 164)
        #expect(summary.countedCount + summary.tooLittleDataCount == summary.territoryCount)
        for result in results where result.verdict.hasEnoughData {
            #expect(result.before.starts >= 30 && result.after.starts >= 30)
        }
        for result in results where result.before.starts < 30 || result.after.starts < 30 {
            #expect(result.verdict == .tooLittleData)
        }
        // Japan: 37 → 34 starts on about the same page views.
        #expect(results.first { $0.territory.alpha2 == "JP" }?.verdict == .aboutTheSame)
        #expect(results.first?.territory.alpha2 == "IN")
    }

    @Test func proceedsAreConvertedToDollars() throws {
        let brazil = try PricingFixtures.territory("BR")
        let proceeds = ResultsEvaluator.proceeds(starts: 10, price: 55, territory: brazil, commission: .smallBusiness)
        #expect(proceeds == PricingFixtures.money("85"))
    }

    @Test func conversionText() {
        #expect(window(31, 0, views: 4800).conversionText == "0.65%")
        #expect(window(0, 0, views: 0).conversionText == "—")
    }
}
