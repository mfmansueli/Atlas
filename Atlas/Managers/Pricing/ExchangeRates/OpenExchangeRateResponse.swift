//
//  OpenExchangeRateResponse.swift
//  Atlas
//

import Foundation

/// open.er-api.com's `/v6/latest/USD` answer: ExchangeRate-API's open
/// access rates, updated once a day.
struct OpenExchangeRateResponse: Decodable, Sendable {
    var result: String
    var baseCode: String
    var timeLastUpdateUnix: Int
    var rates: [String: Double]

    private enum CodingKeys: String, CodingKey {
        case result, rates
        case baseCode = "base_code"
        case timeLastUpdateUnix = "time_last_update_unix"
    }

    enum Problem: Error, Equatable {
        case failed(String)
        case notInDollars(String)
        case invalidRates
    }

    /// The rates, dated by when the provider last updated them.
    func exchangeRates(fetchedAt fetchDate: Date) throws -> ExchangeRates {
        guard result == "success" else { throw Problem.failed(result) }
        guard baseCode == "USD" else { throw Problem.notInDollars(baseCode) }
        let rates = ExchangeRates(
            unitsPerDollar: rates.mapValues { Decimal(exactly: $0) },
            date: Date(timeIntervalSince1970: TimeInterval(timeLastUpdateUnix)),
            fetchDate: fetchDate,
            source: .exchangeRateAPI
        )
        guard rates.isValid else { throw Problem.invalidRates }
        return rates
    }
}
