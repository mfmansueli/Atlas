//
//  PricesByCountryFilters.swift
//  Atlas
//

import Foundation

/// The Filters button's choices over Prices by Country (board 73): regions,
/// and Changed Only, Increases Only, Fallback Only. They apply to the table,
/// the map and the histogram alike.
struct PricesByCountryFilters: Hashable, Sendable {
    var regions: Set<TerritoryRegion> = []
    /// A suggestion or a change waiting in Review & Push.
    var changedOnly = false
    /// The suggestion, or what waits, raises the price.
    var increasesOnly = false
    /// The factor came from a fallback, not the chosen index.
    var fallbackOnly = false

    /// The Filters button's count.
    var count: Int {
        regions.count + [changedOnly, increasesOnly, fallbackOnly].count(where: \.self)
    }

    var isActive: Bool { count > 0 }

    func matches(_ row: CountryPriceRow) -> Bool {
        if !regions.isEmpty, !regions.contains(row.territory.region) { return false }
        if changedOnly, row.shownChange == nil { return false }
        if increasesOnly, row.shownChange?.direction != .increase { return false }
        if fallbackOnly, !row.isFallback { return false }
        return true
    }

    /// What's on, for the line above the table: "Europe · Increases only".
    var summary: String {
        var parts = TerritoryRegion.allCases.filter(regions.contains).map(\.title)
        if changedOnly { parts.append(String(localized: "Changed only", comment: "kind:label")) }
        if increasesOnly { parts.append(String(localized: "Increases only", comment: "kind:label")) }
        if fallbackOnly { parts.append(String(localized: "Fallback only", comment: "kind:label")) }
        return parts.joined(separator: " · ")
    }

    /// "Europe · Increases only · 2 of 40 shown".
    func line(shown: Int, of total: Int) -> String {
        let count = String(localized: "\(shown) of \(total) shown", comment: "kind:hint")
        return summary.isEmpty ? count : "\(summary) · \(count)"
    }
}
