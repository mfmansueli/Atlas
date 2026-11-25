//
//  ExchangeRatesFile.swift
//  Atlas
//

import Foundation

/// The JSON of `ExchangeRatesSnapshot.json` (written by
/// `scripts/price-index/fetch_price_index.py`) and of the store's cache:
/// `{ "source", "date": "yyyy-MM-dd", "fetched": ISO 8601, "base": "USD", "rates" }`.
struct ExchangeRatesFile: Codable, Hashable, Sendable {
    var source: ExchangeRateSource
    var date: String
    var fetched: String?
    var base: String
    var rates: [String: Double]

    init(source: ExchangeRateSource, date: String, fetched: String?, base: String = "USD", rates: [String: Double]) {
        self.source = source
        self.date = date
        self.fetched = fetched
        self.base = base
        self.rates = rates
    }

    init(_ rates: ExchangeRates) {
        self.init(
            source: rates.source,
            date: rates.date.map(PriceIndexEdition.dayString) ?? "",
            fetched: rates.fetchDate.map { $0.formatted(.iso8601) },
            rates: rates.unitsPerDollar.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
        )
    }

    /// "2026-11-25T13:47:52Z", or nil.
    private static func parseInstant(_ text: String) -> Date? {
        try? Date(text, strategy: .iso8601)
    }

    enum DecodingProblem: Error, Equatable {
        case notInDollars(String)
        case invalidRates
    }

    /// The rates, read through their shortest decimal form.
    func exchangeRates() throws -> ExchangeRates {
        guard base == "USD" else { throw DecodingProblem.notInDollars(base) }
        let day = try PriceIndexEdition.parseDay(date)
        let fetchDate = fetched.flatMap(Self.parseInstant)
        let rates = ExchangeRates(unitsPerDollar: rates.mapValues { Decimal(exactly: $0) }, date: day, fetchDate: fetchDate, source: source)
        guard rates.isValid else { throw DecodingProblem.invalidRates }
        return rates
    }
}
