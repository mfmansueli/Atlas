//
//  PricesByCountryQuery.swift
//  Atlas
//

import Foundation

/// What Prices by Country shows of a product's rows: the segment, the
/// Filters, the find field and the sort order, and each segment's count.
enum PricesByCountryQuery {
    static func matches(_ row: CountryPriceRow, filter: PricesByCountryFilter) -> Bool {
        switch filter {
        case .all: true
        case .suggested: row.hasSuggestion
        case .setByYou: row.source.isChosen
        case .automatic: row.source == .automatic
        }
    }

    /// The rows the table, map and histogram show, in order.
    static func visible(
        _ rows: [CountryPriceRow],
        filter: PricesByCountryFilter,
        filters: PricesByCountryFilters = PricesByCountryFilters(),
        search: String,
        sortOrder: [KeyPathComparator<CountryPriceRow>]
    ) -> [CountryPriceRow] {
        let shown = rows.filter { $0.matches(search: search) && filters.matches($0) && matches($0, filter: filter) }
        return sorted(shown, by: sortOrder)
    }

    /// Each segment's count, for what the find field and the Filters keep.
    static func counts(
        _ rows: [CountryPriceRow],
        filters: PricesByCountryFilters = PricesByCountryFilters(),
        search: String
    ) -> [PricesByCountryFilter: Int] {
        let found = rows.filter { $0.matches(search: search) && filters.matches($0) }
        return Dictionary(uniqueKeysWithValues: PricesByCountryFilter.allCases.map { filter in
            (filter, found.count { matches($0, filter: filter) })
        })
    }

    /// The column order, or with none the base country first and then by
    /// name, as the prototype lists them.
    static func sorted(_ rows: [CountryPriceRow], by order: [KeyPathComparator<CountryPriceRow>]) -> [CountryPriceRow] {
        guard order.isEmpty else { return rows.sorted(using: order) }
        return rows.sorted { lhs, rhs in
            if lhs.isBase != rhs.isBase { return lhs.isBase }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
