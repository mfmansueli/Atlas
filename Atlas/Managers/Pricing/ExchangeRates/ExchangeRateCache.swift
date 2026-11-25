//
//  ExchangeRateCache.swift
//  Atlas
//

import Foundation

/// Where `ExchangeRateStore` keeps the last rates it fetched.
protocol ExchangeRateCache: Sendable {
    func load() -> ExchangeRates?
    func save(_ rates: ExchangeRates) throws
}
