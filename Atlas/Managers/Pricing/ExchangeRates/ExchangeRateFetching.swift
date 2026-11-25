//
//  ExchangeRateFetching.swift
//  Atlas
//

import Foundation

/// Downloads the day's exchange rates.
protocol ExchangeRateFetching: Sendable {
    func latest() async throws -> ExchangeRates
}
