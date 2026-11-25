//
//  ExchangeRateStore.swift
//  Atlas
//

import Foundation
import Synchronization

/// The exchange rates live pricing uses (`ExchangeRates.current`).
///
/// Starts from the rates bundled with the release, or the cached ones when
/// they're newer, and refreshes from ExchangeRate-API at most once a day in
/// the background, the first time rates are read after a day has passed.
/// Reading never waits for the network; offline keeps what it has, and a
/// failed fetch is retried after an hour at the earliest.
final class ExchangeRateStore: Sendable {
    /// How long fetched rates count as fresh.
    static let refreshInterval: TimeInterval = 24 * 60 * 60
    /// How long to wait after a failed fetch.
    static let retryInterval: TimeInterval = 60 * 60

    static let shared = makeShared()

    private struct State {
        var rates: ExchangeRates
        var lastAttempt: Date?
        var isRefreshing = false
    }

    private let state: Mutex<State>
    private let cache: (any ExchangeRateCache)?
    private let fetcher: (any ExchangeRateFetching)?
    private let now: @Sendable () -> Date

    /// `fetcher` nil never refreshes (unit tests, DEBUG scenes).
    init(
        bundled: ExchangeRates,
        cache: (any ExchangeRateCache)?,
        fetcher: (any ExchangeRateFetching)?,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        var rates = bundled
        if let cached = cache?.load(), cached.isValid, cached.isNewer(than: bundled) { rates = cached }
        state = Mutex(State(rates: rates))
        self.cache = cache
        self.fetcher = fetcher
        self.now = now
    }

    /// The rates now, without waiting. Starts a background refresh when one
    /// is due.
    var rates: ExchangeRates {
        let (rates, starts) = state.withLock { state in
            (state.rates, Self.isDue(state, now: now()) && fetcher != nil && !state.isRefreshing)
        }
        if starts {
            Task.detached(priority: .utility) { [self] in await refreshIfNeeded() }
        }
        return rates
    }

    /// True when the rates are a day old (or undated) and no fetch failed in
    /// the last hour.
    var isRefreshDue: Bool {
        state.withLock { Self.isDue($0, now: now()) }
    }

    /// An answer that can't be used: no dollar, or a rate that isn't positive.
    struct InvalidRates: Error {}

    /// Fetches new rates when due. Returns true when they changed. A failed
    /// or invalid answer keeps the current rates.
    @discardableResult
    func refreshIfNeeded() async -> Bool {
        guard let fetcher else { return false }
        let starts = state.withLock { state in
            guard !state.isRefreshing, Self.isDue(state, now: now()) else { return false }
            state.isRefreshing = true
            state.lastAttempt = now()
            return true
        }
        guard starts else { return false }
        return await (try? fetch(from: fetcher)) != nil
    }

    /// Settings → Price data's Update Now: fetches now, whether or not a
    /// refresh is due, and returns the rates Atlas uses after it. Throws
    /// when the fetch fails or its answer can't be used; the current rates
    /// stay. While another fetch runs, or without a fetcher (unit tests,
    /// DEBUG scenes), returns the current rates.
    func refreshNow() async throws -> ExchangeRates {
        guard let fetcher else { return state.withLock { $0.rates } }
        let starts = state.withLock { state in
            guard !state.isRefreshing else { return false }
            state.isRefreshing = true
            state.lastAttempt = now()
            return true
        }
        guard starts else { return state.withLock { $0.rates } }
        return try await fetch(from: fetcher)
    }

    /// One fetch, with `isRefreshing` already set: keeps and caches valid
    /// rates, and clears the flag either way.
    private func fetch(from fetcher: any ExchangeRateFetching) async throws -> ExchangeRates {
        let fresh: ExchangeRates
        do {
            fresh = try await fetcher.latest()
        } catch {
            state.withLock { $0.isRefreshing = false }
            throw error
        }
        guard fresh.isValid else {
            state.withLock { $0.isRefreshing = false }
            throw InvalidRates()
        }
        var dated = fresh
        dated.fetchDate = fresh.fetchDate ?? now()
        state.withLock { state in
            state.rates = dated
            state.isRefreshing = false
        }
        try? cache?.save(dated)
        return dated
    }

    private static func isDue(_ state: State, now: Date) -> Bool {
        if let attempt = state.lastAttempt, now.timeIntervalSince(attempt) < retryInterval { return false }
        guard let fetched = state.rates.fetchDate ?? state.rates.date else { return true }
        return now.timeIntervalSince(fetched) >= refreshInterval
    }

    private static func makeShared() -> ExchangeRateStore {
        #if DEBUG
        // The sample world's prices were designed against the prototype's
        // rates, so unit tests and DEBUG scenes keep them (in memory, never
        // fetched), except the scenes that show the real bundled data.
        if UnitTestHost.isRunning || DebugScene.requestedID != nil {
            let usesBundled = DebugScene.requestedID.map(PricingIndexDataDebugScenes.usesBundledData) ?? false
            let rates = usesBundled ? (try? ExchangeRates.bundled()) ?? .approximate : .approximate
            return ExchangeRateStore(bundled: rates, cache: InMemoryExchangeRateCache(), fetcher: nil)
        }
        #endif
        return ExchangeRateStore(
            bundled: (try? ExchangeRates.bundled()) ?? .approximate,
            cache: FileExchangeRateCache(),
            fetcher: OpenExchangeRateFetcher()
        )
    }
}
