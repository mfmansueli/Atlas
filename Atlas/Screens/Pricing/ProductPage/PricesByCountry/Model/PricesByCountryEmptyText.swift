//
//  PricesByCountryEmptyText.swift
//  Atlas
//

import Foundation

/// What Prices by Country says when no row is left (board 73): the find
/// field's text when it matches nothing, else what the filter being empty
/// means.
struct PricesByCountryEmptyText: Equatable {
    let text: String
    let symbol: String
    /// What Find holds when it matches nothing: the inline empty state
    /// (board 74) with Clear Search.
    var query: String?

    static func make(filter: PricesByCountryFilter, search: String) -> Self {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return Self(
                text: String(localized: "No results for “\(query)”", comment: "kind:empty"),
                symbol: "magnifyingglass",
                query: query
            )
        }
        switch filter {
        case .all:
            return Self(text: String(localized: "No countries or regions.", comment: "kind:empty"), symbol: "globe")
        case .suggested:
            return Self(text: String(localized: "No suggested prices left.", comment: "kind:empty"), symbol: "checkmark.circle")
        case .setByYou:
            return Self(
                text: String(localized: "No prices set by you. Every country follows the base price.", comment: "kind:empty"),
                symbol: "globe"
            )
        case .automatic:
            return Self(text: String(localized: "Every price here is set by you.", comment: "kind:empty"), symbol: "person.crop.circle")
        }
    }
}
