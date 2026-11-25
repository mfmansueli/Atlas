//
//  CountryPriceMapTile.swift
//  Atlas
//

import Foundation

/// One country on Prices by Country's map (board 73, `pr-prod-map`): its
/// two-letter code and feels-like ratio as text on a `PriceLevel` colour,
/// with a ring where a suggestion waits. Tiles sit in their region's group.
struct CountryPriceMapTile: Identifiable, Hashable, Sendable {
    /// Alpha-3.
    var id: String
    var code: String
    var name: String
    var region: TerritoryRegion
    /// The feels-like ratio of the price shown (today's or the suggested
    /// one); nil without a factor.
    var ratio: Double?
    var ratioText: String
    var hasSuggestion: Bool
    /// "Brazil, R$ 249,90, feels like 2.1×".
    var accessibilityText: String

    var level: PriceLevel? { ratio.map(PriceLevel.init(ratio:)) }

    /// The rows' tiles, coloured by today's prices or by the suggested ones.
    static func tiles(_ rows: [CountryPriceRow], showsSuggested: Bool) -> [CountryPriceMapTile] {
        rows.map { row in
            let price = showsSuggested ? (row.suggestion?.customerPrice ?? row.shownPrice) : row.shownPrice
            let ratioText = row.feelsLike?.ratioText(price) ?? "—"
            let priceText = row.currency.format(price)
            return CountryPriceMapTile(
                id: row.id,
                code: row.territory.alpha2,
                name: row.territory.name,
                region: row.territory.region,
                ratio: row.feelsLike?.ratio(price),
                ratioText: ratioText,
                hasSuggestion: row.hasSuggestion,
                accessibilityText: String(localized: "\(row.territory.name), \(priceText), feels like \(ratioText)", comment: "kind:accessibility-label")
            )
        }
    }

    /// The tiles by region, in the regions' order, each by name.
    static func grouped(_ tiles: [CountryPriceMapTile]) -> [(region: TerritoryRegion, tiles: [CountryPriceMapTile])] {
        TerritoryRegion.allCases.compactMap { region in
            let inRegion = tiles.filter { $0.region == region }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return inRegion.isEmpty ? nil : (region, inRegion)
        }
    }
}
