//
//  CountryPriceHistogram.swift
//  Atlas
//

import Foundation

/// Prices by Country's histogram (board 73, `pr-prod-hist`): how many
/// countries sit in each $5 of price in US dollars, today's prices and the
/// suggested ones side by side, with the US base price marked.
struct CountryPriceHistogram: Hashable, Sendable {
    enum Series: String, CaseIterable, Hashable, Sendable {
        case now
        case suggested

        var title: String {
            switch self {
            case .now: String(localized: "Now", comment: "kind:label")
            case .suggested: String(localized: "Suggested", comment: "kind:label")
            }
        }
    }

    struct Bin: Identifiable, Hashable, Sendable {
        /// The bin's lower edge in US dollars: 0, 5, 10…
        var lowerBound: Int
        var series: Series
        var count: Int

        var id: String { "\(series.rawValue).\(lowerBound)" }

        /// "$10–15".
        var label: String { "$\(lowerBound)–\(lowerBound + CountryPriceHistogram.binWidth)" }
    }

    static let binWidth = 5

    var bins: [Bin]
    /// The base price in US dollars, for the dashed line; nil without a rate.
    var baseDollars: Double?
    /// Some country has a suggestion, so the suggested bars show.
    var hasSuggestions: Bool

    init(rows: [CountryPriceRow], basePrice: Decimal?, baseCurrency: String) {
        let now = rows.compactMap { $0.dollars($0.shownPrice)?.doubleValue }
        let suggested = rows.compactMap { row in row.dollars(row.suggestion?.customerPrice ?? row.shownPrice)?.doubleValue }
        hasSuggestions = rows.contains(where: \.hasSuggestion)
        let top = Int(((now + suggested).max() ?? 0) / Double(Self.binWidth)) * Self.binWidth
        let edges = Array(stride(from: 0, through: top, by: Self.binWidth))
        var bins = Self.count(now, edges: edges, series: .now)
        if hasSuggestions { bins += Self.count(suggested, edges: edges, series: .suggested) }
        self.bins = bins
        baseDollars = basePrice.flatMap { ExchangeRates.approximate.dollars($0, currency: baseCurrency)?.doubleValue }
    }

    var maximumCount: Int { bins.map(\.count).max() ?? 0 }

    private static func count(_ values: [Double], edges: [Int], series: Series) -> [Bin] {
        var counts = [Int: Int]()
        for value in values {
            let edge = Int(max(0, value) / Double(binWidth)) * binWidth
            counts[edge, default: 0] += 1
        }
        return edges.map { Bin(lowerBound: $0, series: series, count: counts[$0] ?? 0) }
    }
}
