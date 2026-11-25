//
//  PriceDataSummaryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → Price data (board 76): the bundled indexes in the Source
/// column's pattern, when they were bundled, and the exchange rates'
/// source and day.
@Suite("PriceDataSummary")
struct PriceDataSummaryTests {
    private let rates = ExchangeRates(
        unitsPerDollar: ["USD": 1, "BRL": 5], date: PricingSampleData.date("2026-11-25"), source: .exchangeRateAPI
    )

    @Test func theSampleSnapshotListsEachIndexBySourceAndEdition() {
        let snapshot = PricingSampleData.shared.snapshot
        let summary = PriceDataSummary.make(snapshot: snapshot, rates: rates)
        #expect(summary.indexes == ["Big Mac · Jan 2026", "World Bank · 2024", "IMF · Apr 2026"])
        #expect(summary.snapshotLine == "Bundled with Atlas on \(PricingText.date(snapshot.snapshotDate)) · works offline")
        #expect(summary.isApproximate == snapshot.isApproximate)
    }

    @Test func theRatesLineIsTheProvidersWithItsDay() {
        let summary = PriceDataSummary.make(snapshot: PricingSampleData.shared.snapshot, rates: rates)
        #expect(summary.ratesLine == rates.sourceLine)
        #expect(summary.ratesURL == ExchangeRateSource.exchangeRateAPI.url)
        #expect(PriceDataSummary.make(snapshot: nil, rates: .approximate).ratesURL == nil)
    }

    @Test func anUnreadableSnapshotSaysSo() {
        let summary = PriceDataSummary.make(snapshot: nil, rates: rates)
        #expect(summary.indexes.isEmpty)
        #expect(summary.snapshotLine == "Couldn’t read the bundled index data")
    }
}
