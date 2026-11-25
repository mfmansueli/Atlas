//
//  MCPPriceTrustJSON.swift
//  Atlas
//

import Foundation

/// How the price tools write what a price stands on: how sure, the sales
/// windows, the sales state, index trust, dates and exchange rates.
enum MCPPriceTrustJSON {
    /// "notVerySure", "fairlySure" or "sure".
    static func level(_ howSure: HowSure) -> String {
        switch howSure {
        case .notVerySure: "notVerySure"
        case .fairlySure: "fairlySure"
        case .sure: "sure"
        }
    }

    /// `{level, word, confidence}`: the word Atlas shows and the 1–3 a
    /// proposal's `confidence` takes.
    static func howSure(_ howSure: HowSure) -> JSONValue {
        [
            "level": .string(level(howSure)),
            "word": .string(howSure.word),
            "confidence": .int(howSure.rawValue),
        ]
    }

    /// The level with its one line, one number.
    static func howSure(_ confidence: PriceConfidence) -> JSONValue {
        var object = howSure(confidence.howSure).objectValue ?? [:]
        object["reason"] = .string(confidence.reason)
        return .object(object)
    }

    /// One window: page views, downloads, starts, trial and paid starts,
    /// and proceeds in US dollars.
    static func signal(_ signal: SalesSignal) -> JSONValue {
        [
            "pageViews": .int(signal.pageViews),
            "downloads": .int(signal.downloads),
            "starts": .int(signal.starts),
            "trialStarts": .int(signal.trialStarts),
            "paidStarts": .int(signal.paidStarts),
            "proceedsUSD": MCPPriceValue.json(signal.proceeds.rounded(scale: 2)),
        ]
    }

    static func availability(_ availability: PricingSalesData.Availability) -> String {
        switch availability {
        case .available: "available"
        case .noSalesYet: "noSalesYet"
        case .roleCannotRead: "roleCannotRead"
        case .turnedOff: "turnedOff"
        case .notRead: "notRead"
        }
    }

    static func trust(_ trust: PriceIndexTrust) -> String {
        switch trust {
        case .exact: "exact"
        case .fallback: "fallback"
        case .approximate: "approximate"
        case .stale: "stale"
        case .missing: "missing"
        }
    }

    /// Where a factor came from: an index, its region's median, none.
    static func basis(_ kind: PriceProvenance.Kind) -> String {
        switch kind {
        case .index: "index"
        case .regionMedian: "regionMedian"
        case .equalized: "equalized"
        case .regionalTier: "regionalTier"
        case .excluded: "excluded"
        }
    }

    /// "2026-11-22", in GMT.
    static func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    /// The day's rates behind every US dollar amount: their source, the
    /// day the source published them and when Atlas read them.
    static func exchangeRates(_ rates: ExchangeRates) -> JSONValue {
        var object: [String: JSONValue] = [
            "source": .string(rates.source.rawValue),
            "line": .string(rates.detailText),
        ]
        if let date = rates.date { object["date"] = .string(day(date)) }
        if let fetched = rates.fetchDate { object["fetched"] = .string(fetched.formatted(.iso8601)) }
        return .object(object)
    }
}
