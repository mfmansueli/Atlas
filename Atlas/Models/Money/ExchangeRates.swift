//
//  ExchangeRates.swift
//  Atlas
//

import Foundation

/// Market exchange rates as units of each currency per US dollar, for In
/// US$, the map, the histogram, proceeds and "feels like".
///
/// App Store Connect doesn't publish exchange rates. Live code reads
/// `current`: ExchangeRate-API's daily rates, bundled with each release
/// (`ExchangeRatesSnapshot.json`) and refreshed once a day by
/// `ExchangeRateStore`. `approximate` holds the design prototype's
/// illustrative rates, for DEBUG scenes and the sample world only.
struct ExchangeRates: Hashable, Sendable {
    /// Units of the currency per US dollar, e.g. `"BRL": 5.5`.
    var unitsPerDollar: [String: Decimal]
    /// The day the source published these rates.
    var date: Date?
    /// When Atlas (or the snapshot script) downloaded them.
    var fetchDate: Date?
    var source: ExchangeRateSource = .sample

    /// The rates live code uses: `ExchangeRateStore.shared`'s.
    static var current: ExchangeRates { ExchangeRateStore.shared.rates }

    /// The prototype's illustrative rates (approximate, October 2026).
    static let approximate = ExchangeRates(unitsPerDollar: approximateRates.mapValues { Decimal(exactly: $0) }, source: .sample)

    private static let approximateRates: [String: Double] = [
        "USD": 1,
        "CAD": 1.38,
        "MXN": 18.5,
        "BRL": 5.5,
        "CLP": 950,
        "COP": 4100,
        "PEN": 3.75,
        "EUR": 0.88,
        "GBP": 0.76,
        "CHF": 0.82,
        "NOK": 10.5,
        "SEK": 9.8,
        "DKK": 6.6,
        "PLN": 3.8,
        "CZK": 22,
        "HUF": 350,
        "RON": 4.4,
        "TRY": 42,
        "KZT": 520,
        "ILS": 3.5,
        "AED": 3.67,
        "SAR": 3.75,
        "QAR": 3.64,
        "EGP": 50,
        "ZAR": 18,
        "NGN": 1550,
        "TZS": 2600,
        "JPY": 150,
        "KRW": 1400,
        "CNY": 7.2,
        "HKD": 7.8,
        "TWD": 31,
        "SGD": 1.3,
        "MYR": 4.3,
        "THB": 33,
        "IDR": 16300,
        "VND": 26000,
        "PHP": 58,
        "INR": 87,
        "PKR": 282,
        "AUD": 1.53,
        "NZD": 1.7,
    ]

    /// `amount` in US dollars, or nil for an unknown currency.
    func dollars(_ amount: Decimal, currency code: String) -> Decimal? {
        guard let rate = unitsPerDollar[code.uppercased()], rate > 0 else { return nil }
        return amount / rate
    }

    /// Usable rates: the dollar is 1 and every rate is positive.
    var isValid: Bool {
        unitsPerDollar["USD"] == 1 && !unitsPerDollar.isEmpty && unitsPerDollar.values.allSatisfy { $0 > 0 }
    }

    /// Published later than `other`, or as late and fetched later.
    func isNewer(than other: ExchangeRates) -> Bool {
        let mine = date ?? .distantPast, theirs = other.date ?? .distantPast
        if mine != theirs { return mine > theirs }
        return (fetchDate ?? .distantPast) > (other.fetchDate ?? .distantPast)
    }

    /// Where the rates come from and their day, the Source column's pattern
    /// (board 76): "Rates by ExchangeRate-API · 25 Nov 2026", or "Sample
    /// exchange rates, not live quotes". Settings → Price data, the Prices
    /// by Country footer and the product's Details say it this way.
    var sourceLine: String {
        guard source != .sample, let date else {
            return String(localized: "Sample exchange rates, not live quotes", comment: "kind:hint")
        }
        let day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
        return String(localized: "\(source.attribution) · \(day)", comment: "kind:hint")
    }

    /// The details line: "Exchange rates of 25 Nov 2026 · Rates by
    /// ExchangeRate-API", or "Sample exchange rates, not live quotes".
    var detailText: String {
        guard source != .sample, let date else {
            return String(localized: "Sample exchange rates, not live quotes", comment: "kind:hint")
        }
        let day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
        return String(localized: "Exchange rates of \(day) · \(source.attribution)", comment: "kind:hint")
    }
}
