//
//  ConversionPoolingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Country → region → world shrinkage of conversion.
@Suite("ConversionPooling")
struct ConversionPoolingTests {
    /// Europe: three big countries and Portugal with 20 page views.
    private let europe: [String: SalesSignal] = [
        "DEU": SalesSignal(pageViews: 2000, starts: 60),
        "FRA": SalesSignal(pageViews: 2000, starts: 40),
        "GBR": SalesSignal(pageViews: 2000, starts: 50),
        "PRT": SalesSignal(pageViews: 20, starts: 0),
    ]

    /// The Americas: the United States with most of the traffic.
    private let americas: [String: SalesSignal] = [
        "USA": SalesSignal(pageViews: 50000, starts: 1500),
        "BRA": SalesSignal(pageViews: 1000, starts: 10),
        "MEX": SalesSignal(pageViews: 1000, starts: 10),
        "CAN": SalesSignal(pageViews: 1000, starts: 20),
    ]

    @Test func aThinCountryMovesTowardItsRegion() throws {
        let pooling = ConversionPooling(signals: europe)
        let prior = try #require(pooling.regionPriors[.europe])
        let portugal = try #require(pooling.estimate(for: "PRT"))
        #expect(portugal.region == .europe)
        #expect(portugal.rate > 0)
        #expect(abs(portugal.rate - prior.mean) < 0.0005)
        #expect(portugal.ownWeight < ConversionPooling.borrowingWeight)
        #expect(portugal.leansOnRegion)
        #expect(portugal.regionTotal == SalesSignal(pageViews: 6020, starts: 150))
    }

    @Test func aBigCountryKeepsItsOwnRate() throws {
        let pooling = ConversionPooling(signals: americas)
        let unitedStates = try #require(pooling.estimate(for: "USA"))
        #expect(abs(unitedStates.rate - 0.03) < 0.001)
        #expect(unitedStates.ownWeight > 0.9)
        #expect(!unitedStates.leansOnRegion)
    }

    @Test func anEmptyRegionFallsBackToTheWorld() throws {
        let pooling = ConversionPooling(signals: europe.merging(americas) { first, _ in first })
        let world = try #require(pooling.world)
        let africa = try #require(pooling.regionPriors[.africaMiddleEast])
        #expect(abs(africa.mean - world.mean) < 1e-12)
        #expect(africa.strength == world.strength)
        let egypt = try #require(pooling.estimate(for: "EGY"))
        #expect(egypt.ownWeight == 0)
        #expect(abs(egypt.rate - world.mean) < 1e-12)
        #expect(egypt.own == .zero)
    }

    @Test func aThinRegionBorrowsFromTheWorld() throws {
        var signals = europe.merging(americas) { first, _ in first }
        signals["JPN"] = SalesSignal(pageViews: 500, starts: 10)
        let pooling = ConversionPooling(signals: signals)
        let world = try #require(pooling.world)
        let asia = try #require(pooling.regionPriors[.asiaPacific])
        #expect(asia.strength == world.strength)
        #expect(abs(asia.mean - world.posteriorMean(starts: 10, pageViews: 500)) < 1e-12)
    }

    @Test func aRegionWithThreeCountriesHasItsOwnPrior() throws {
        let pooling = ConversionPooling(signals: europe.merging(americas) { first, _ in first })
        let europePrior = try #require(pooling.regionPriors[.europe])
        let americasPrior = try #require(pooling.regionPriors[.americas])
        #expect(abs(europePrior.mean - 150.0 / 6020) < 1e-12)
        #expect(abs(americasPrior.mean - 1540.0 / 53000) < 1e-12)
    }

    @Test func trialsCountOnlyWhenTheProductHasThem() {
        #expect(!ConversionPooling(signals: europe).usesTrials)
        var signals = europe
        signals["DEU"]?.trialStarts = 12
        #expect(ConversionPooling(signals: signals).usesTrials)
    }

    @Test func withoutPageViewsThereIsNothingToPool() {
        #expect(ConversionPooling.empty.estimate(for: "BRA") == nil)
        #expect(ConversionPooling(signals: ["BRA": SalesSignal(pageViews: 0, starts: 0)]).estimate(for: "BRA") == nil)
        #expect(ConversionPooling(signals: europe).estimate(for: "XXX") == nil)
    }

    @Test func salesThatDontCountAreNotPooled() {
        let sales = PricingSalesData(availability: .roleCannotRead, signals: europe)
        #expect(sales.pooling().estimate(for: "PRT") == nil)
        let read = PricingSalesData(availability: .available, signals: europe)
        #expect(read.pooling().estimate(for: "PRT") != nil)
    }

    @Test func evidenceCarriesThePoolAndTheGrid() {
        let sales = PricingSalesData(
            availability: .available,
            signals: europe,
            recentSignals: ["PRT": SalesSignal(pageViews: 8, starts: 0)],
            baseTerritoryID: "DEU",
            readThrough: PricingSampleData.date("2026-11-22")
        )
        let evidence = sales.evidence(for: "PRT", pooling: sales.pooling(), hasRealGrid: true)
        #expect(evidence.canReadSales)
        #expect(evidence.availability == .available)
        #expect(evidence.hasRealGrid)
        #expect(evidence.pooled?.region == .europe)
        #expect(evidence.basePooled?.territoryID == "DEU")
        #expect(evidence.recentSignal?.pageViews == 8)
        #expect(evidence.readThrough == PricingSampleData.date("2026-11-22"))
        let off = PricingSalesData(availability: .turnedOff).evidence(for: "PRT", pooling: .empty, hasRealGrid: true)
        #expect(!off.canReadSales)
        #expect(off.availability == .turnedOff)
    }
}
