//
//  DebugPricingSalesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The sample sales other agents' scenes and tests read: a thin country, a
/// region with traffic, a past change with both windows.
@MainActor
@Suite("DEBUG pricing sales")
struct DebugPricingSalesTests {
    @Test(arguments: PricingSalesDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(PricingSalesDebugScenes.view(for: id) != nil)
    }

    @Test func readSalesHaveEachKindOfCountry() throws {
        let product = try PricingModelFixtures.annual()
        let sales = DebugPricingSales.salesData(for: product)
        #expect(sales.availability == .available)
        #expect(sales.readThrough == DebugPricingSales.through.date)
        let portugal = try #require(sales.signals["PRT"])
        #expect(portugal.pageViews == 40)
        #expect(portugal.trialStarts == 1)
        let europe = ["DEU", "FRA", "ESP", "ITA"].compactMap { sales.signals[$0] }.reduce(SalesSignal.zero, +)
        #expect(europe.pageViews >= 300)
        #expect(europe.trialStarts >= 10)
        let brazil = try #require(sales.priorChanges["BRA"])
        #expect(brazil.before.starts == 31)
        #expect(brazil.after.starts == 68)
        #expect(brazil.previousPrice == PricingFixtures.money("219.9"))
    }

    @Test(arguments: [PricingSalesData.Availability.noSalesYet, .roleCannotRead, .turnedOff, .notRead])
    func eachStateReadsAsItself(availability: PricingSalesData.Availability) throws {
        let sales = try DebugPricingSales.salesData(for: PricingModelFixtures.annual(), availability: availability)
        #expect(sales.availability == availability)
        #expect(sales.priorChanges.isEmpty)
        #expect(sales.signals.values.allSatisfy { $0.starts == 0 })
    }

    @Test func noSalesYetStillHasPageViews() throws {
        let sales = try DebugPricingSales.salesData(for: PricingModelFixtures.annual(), availability: .noSalesYet)
        #expect(sales.canRead)
        #expect(sales.signals["USA"].map { $0.pageViews > 0 } == true)
    }

    @Test func resultWindowsGiveOneTerritoryPerVerdict() {
        let verdicts = DebugPricingSales.resultWindows.mapValues { ResultsEvaluator.verdict(before: $0.before, after: $0.after) }
        #expect(verdicts == ["BRA": .better, "JPN": .worse, "DEU": .aboutTheSame, "PRT": .tooLittleData])
    }
}
#endif
