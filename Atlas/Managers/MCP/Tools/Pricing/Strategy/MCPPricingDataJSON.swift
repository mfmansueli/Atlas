//
//  MCPPricingDataJSON.swift
//  Atlas
//

import Foundation

/// What get_pricing_strategy says about the data suggestions stand on:
/// each index's edition (published, data year, fetched, coverage, fallbacks,
/// stale), the day's exchange rates and the thresholds of how sure.
enum MCPPricingDataJSON {
    static func json(snapshot: PriceIndexSnapshot, rates: ExchangeRates, asOf: Date = .now) -> JSONValue {
        let indices: [JSONValue] = PriceIndexSource.allCases.compactMap { source in
            snapshot.index(source).map { index(source, $0, asOf: asOf) }
        }
        return [
            "approximate": .bool(snapshot.isApproximate),
            "indices": .array(indices),
            "exchangeRates": MCPPriceTrustJSON.exchangeRates(rates),
            "howSureRule": howSureRule,
        ]
    }

    /// One index's edition.
    static func index(_ source: PriceIndexSource, _ index: PriceIndex, asOf: Date) -> JSONValue {
        let edition = index.edition
        var object: [String: JSONValue] = [
            "source": .string(source.rawValue),
            "name": .string(source.name),
            "publisher": .string(index.publisher),
            "edition": .string(edition.label),
            "label": .string(edition.provenanceLabel),
            "published": .string(MCPPriceTrustJSON.day(edition.date)),
            "coverage": .int(index.coverage),
            "fallbacks": .int(index.fallbackCount),
            "stale": .bool(edition.isOlder(thanMonths: PriceIndexSnapshot.staleAfterMonths, asOf: asOf)),
        ]
        if let year = edition.dataYear { object["dataYear"] = .int(year) }
        if let fetched = edition.fetchDate { object["fetched"] = .string(MCPPriceTrustJSON.day(fetched)) }
        if let newer = edition.newerEdition { object["newerEdition"] = .string(newer) }
        return .object(object)
    }

    /// `PriceConfidenceRule`'s thresholds, as numbers.
    static let howSureRule: JSONValue = [
        "notVerySure": """
        Purchasing power alone: no sales read or none yet, too few, an approximate index or one over 18 months old, \
        or Apple's price points not read.
        """,
        "fairlySure": [
            "pageViews": .int(PriceConfidenceRule.minimumPageViews),
            "trialStarts": .int(PriceConfidenceRule.minimumTrials),
            "days": .int(PricingSalesData.windowDays),
            "orRegion": "A thin country with page views of its own counts its region's.",
        ],
        "sure": [
            "daysEachSide": .int(PriceConfidenceRule.minimumDaysEachSide),
            "startsEachSide": .int(PriceConfidenceRule.minimumStartsEachSide),
            "interval": "The 90% range for the change's effect on conversion excludes zero.",
        ],
        "staleAfterMonths": .int(PriceIndexSnapshot.staleAfterMonths),
    ]
}
