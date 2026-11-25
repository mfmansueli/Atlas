//
//  ExchangeRateStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ExchangeRateStore`: bundled rates first, cached ones when newer, one
/// background refresh a day, offline keeps what it has. Never touches the
/// network or the person's files: fetchers and caches are in memory.
@Suite("ExchangeRateStore")
struct ExchangeRateStoreTests {
    /// Answers with `rates` or throws, counting calls.
    final class StubFetcher: ExchangeRateFetching, @unchecked Sendable {
        var rates: ExchangeRates?
        private(set) var calls = 0

        init(_ rates: ExchangeRates?) {
            self.rates = rates
        }

        func latest() async throws -> ExchangeRates {
            calls += 1
            guard let rates else { throw URLError(.notConnectedToInternet) }
            return rates
        }
    }

    private static func day(_ text: String) -> Date {
        PricingSampleData.date(text)
    }

    private static func rates(brl: String, on day: String, fetched: Date? = nil) -> ExchangeRates {
        ExchangeRates(
            unitsPerDollar: ["USD": 1, "BRL": PricingFixtures.money(brl)],
            date: Self.day(day),
            fetchDate: fetched ?? Self.day(day),
            source: .exchangeRateAPI
        )
    }

    private let bundled = Self.rates(brl: "5.5", on: "2026-11-20")

    @Test func startsFromTheBundledRates() {
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: nil)
        #expect(store.rates == bundled)
    }

    @Test func newerCachedRatesWin() {
        let cached = Self.rates(brl: "5.9", on: "2026-11-24")
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(cached), fetcher: nil)
        #expect(store.rates == cached)
    }

    @Test func olderCachedRatesLoseToANewerRelease() {
        let cached = Self.rates(brl: "5.1", on: "2026-10-01")
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(cached), fetcher: nil)
        #expect(store.rates == bundled)
    }

    @Test func refreshIsSkippedWhileFresh() async {
        let fetcher = StubFetcher(Self.rates(brl: "6", on: "2026-11-21"))
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: fetcher) {
            Self.day("2026-11-20").addingTimeInterval(3600)
        }
        #expect(!store.isRefreshDue)
        #expect(await store.refreshIfNeeded() == false)
        #expect(fetcher.calls == 0)
        #expect(store.rates == bundled)
    }

    @Test func aDayLaterItFetchesAndCaches() async {
        let fresh = Self.rates(brl: "5.89", on: "2026-11-25")
        let fetcher = StubFetcher(fresh)
        let cache = InMemoryExchangeRateCache()
        let store = ExchangeRateStore(bundled: bundled, cache: cache, fetcher: fetcher) { Self.day("2026-11-25") }
        #expect(store.isRefreshDue)
        #expect(await store.refreshIfNeeded())
        #expect(fetcher.calls == 1)
        #expect(store.rates.dollars(PricingFixtures.money("58.9"), currency: "BRL") == 10)
        #expect(cache.load() == store.rates)
        #expect(!store.isRefreshDue)
        #expect(await store.refreshIfNeeded() == false)
        #expect(fetcher.calls == 1)
    }

    @Test func offlineKeepsTheRatesAndWaitsAnHour() async {
        let fetcher = StubFetcher(nil)
        let now = Self.day("2026-11-25")
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: fetcher) { now }
        #expect(await store.refreshIfNeeded() == false)
        #expect(store.rates == bundled)
        #expect(fetcher.calls == 1)
        #expect(!store.isRefreshDue, "a failed fetch is retried after an hour at the earliest")
        #expect(await store.refreshIfNeeded() == false)
        #expect(fetcher.calls == 1)
    }

    @Test func invalidAnswersAreRefused() async {
        let broken = ExchangeRates(unitsPerDollar: ["USD": 1, "BRL": 0], date: Self.day("2026-11-25"), source: .exchangeRateAPI)
        let store = ExchangeRateStore(bundled: bundled, cache: InMemoryExchangeRateCache(), fetcher: StubFetcher(broken)) {
            Self.day("2026-11-25")
        }
        #expect(await store.refreshIfNeeded() == false)
        #expect(store.rates == bundled)
    }

    @Test func withoutAFetcherNothingRefreshes() async {
        let store = ExchangeRateStore(bundled: bundled, cache: nil, fetcher: nil) { Self.day("2027-01-01") }
        #expect(await store.refreshIfNeeded() == false)
        #expect(store.rates == bundled)
    }

    @Test func unitTestsUseTheSampleRates() {
        #expect(ExchangeRates.current == .approximate)
        #expect(ExchangeRates.current.source == .sample)
    }

    @Test func theFileCacheRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "atlas-rates-\(UUID().uuidString)/ExchangeRates.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let cache = FileExchangeRateCache(url: url)
        #expect(cache.load() == nil)
        let rates = Self.rates(brl: "5.89", on: "2026-11-25", fetched: Date(timeIntervalSince1970: 1_795_600_000))
        try cache.save(rates)
        #expect(cache.load() == rates)
    }
}
