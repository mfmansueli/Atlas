//
//  FileExchangeRateCache.swift
//  Atlas
//

import Foundation

/// The last fetched rates in `Application Support/Atlas/Pricing/ExchangeRates.json`.
struct FileExchangeRateCache: ExchangeRateCache {
    static let defaultURL = URL.applicationSupportDirectory.appending(path: "Atlas/Pricing/ExchangeRates.json")

    var url: URL = Self.defaultURL

    func load() -> ExchangeRates? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? ExchangeRates(jsonData: data)
    }

    func save(_ rates: ExchangeRates) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try rates.jsonData().write(to: url, options: .atomic)
    }
}
