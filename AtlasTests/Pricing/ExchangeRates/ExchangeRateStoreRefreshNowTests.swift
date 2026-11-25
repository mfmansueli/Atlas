//
//  ExchangeRateStoreRefreshNowTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → Price data's Update Now (board 76): it fetches whether or not
/// a day has passed, a failure keeps the rates Atlas has, and the rates
/// line names the source and the day. In memory only.
@Suite("ExchangeRateStore · Update Now")
struct ExchangeRateStoreRefreshNowTests {
    private typealias StubFetcher = ExchangeRateStoreTests.StubFetcher

    private static func rates(brl: String, on day: String) -> ExchangeRates {
        ExchangeRates(
            unitsPerDollar: ["USD": 1, "BRL": PricingFixtures.money(brl)],
            date: PricingSampleData.date(day),
            fetchDate: PricingSampleData.date(day),
            source: .exchangeRateAPI
        )
    }

    private let bundled = Self.rates(brl: "5.5", on: "2026-11-25")

    @Test func updateNowFetchesEvenWhenTheRatesAreFresh() async throws {
        let fresh = Self.rates(brl: "5.6", on: "2026-11-25")
        let fetcher = StubFetcher(fresh)
        let cache = InMemoryExchangeRateCache()
        let store = ExchangeRateStore(bundled: bundled, cache: cache, fetcher: fetcher) { PricingSampleData.date("2026-11-25") }
        #expect(!store.isRefreshDue)
        let updated = try await store.refreshNow()
        #expect(fetcher.calls == 1)
        #expect(updated == fresh)
        #expect(store.rates == fresh)
        #expect(cache.load() == fresh)
    }

    @Test func aFailedUpdateThrowsAndKeepsTheRates() async throws {
        let fetcher = StubFetcher(nil)
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: fetcher) { PricingSampleData.date("2026-11-25") }
        await #expect(throws: URLError.self) { try await store.refreshNow() }
        #expect(store.rates == bundled)
        // The next Update Now tries again: a failure doesn't lock it.
        fetcher.rates = Self.rates(brl: "5.7", on: "2026-11-25")
        #expect(try await store.refreshNow().unitsPerDollar["BRL"] == PricingFixtures.money("5.7"))
    }

    @Test func anUnusableAnswerIsAFailure() async {
        let fetcher = StubFetcher(ExchangeRates(unitsPerDollar: ["BRL": 5], date: .now, source: .exchangeRateAPI))
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: fetcher) { PricingSampleData.date("2026-11-25") }
        await #expect(throws: ExchangeRateStore.InvalidRates.self) { try await store.refreshNow() }
        #expect(store.rates == bundled)
    }

    @Test func withoutAFetcherItKeepsTheRates() async throws {
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: nil)
        #expect(try await store.refreshNow() == bundled)
    }

    @Test func theRatesLineNamesTheSourceAndTheDay() throws {
        let line = bundled.sourceLine
        #expect(line.hasPrefix("Rates by ExchangeRate-API · "))
        let day = try #require(bundled.date).formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
        #expect(line == "Rates by ExchangeRate-API · \(day)")
        #expect(ExchangeRates.approximate.sourceLine == "Sample exchange rates, not live quotes")
    }
}
