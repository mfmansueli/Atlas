//
//  InMemoryExchangeRateCache.swift
//  Atlas
//

import Foundation
import Synchronization

/// A cache that lives as long as the store: for unit tests and DEBUG
/// scenes, which never touch the person's files.
final class InMemoryExchangeRateCache: ExchangeRateCache {
    private let stored: Mutex<ExchangeRates?>

    init(_ rates: ExchangeRates? = nil) {
        stored = Mutex(rates)
    }

    func load() -> ExchangeRates? {
        stored.withLock { $0 }
    }

    func save(_ rates: ExchangeRates) throws {
        stored.withLock { $0 = rates }
    }
}
