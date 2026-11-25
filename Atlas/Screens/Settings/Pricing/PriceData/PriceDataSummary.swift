//
//  PriceDataSummary.swift
//  Atlas
//

import Foundation

/// What Settings → Price data says (board 76): each bundled price index by
/// its source and edition ("World Bank · 2025", the Source column's
/// pattern), when the snapshot was bundled, and where the exchange rates
/// come from with their day.
struct PriceDataSummary: Equatable, Sendable {
    /// "World Bank · 2025", one per index the bundled snapshot has.
    var indexes: [String]
    /// "Bundled with Atlas on Apr 30, 2026 · works offline".
    var snapshotLine: String
    /// "Rates by ExchangeRate-API · 25 Nov 2026".
    var ratesLine: String
    /// The provider's page, linked from the rates line as its terms ask.
    var ratesURL: URL?
    /// The bundled values are the sample's, not the publishers'.
    var isApproximate: Bool

    /// The indexes Settings lists, in the picker's order.
    static let sources: [PriceIndexSource] = [.bigMac, .worldBank, .imf]

    static func make(snapshot: PriceIndexSnapshot?, rates: ExchangeRates) -> PriceDataSummary {
        guard let snapshot else {
            return PriceDataSummary(
                indexes: [],
                snapshotLine: String(localized: "Couldn’t read the bundled index data", comment: "kind:error"),
                ratesLine: rates.sourceLine,
                ratesURL: rates.source.url,
                isApproximate: false
            )
        }
        let indexes = sources.compactMap { source in
            snapshot.index(source).map { PriceSourceText.text(source, edition: $0.edition) }
        }
        let date = PricingText.date(snapshot.snapshotDate)
        return PriceDataSummary(
            indexes: indexes,
            snapshotLine: String(localized: "Bundled with Atlas on \(date) · works offline", comment: "kind:hint"),
            ratesLine: rates.sourceLine,
            ratesURL: rates.source.url,
            isApproximate: snapshot.isApproximate
        )
    }
}
