//
//  PricesByCountryFilter.swift
//  Atlas
//

import Foundation

/// The filter above a product's Prices by Country table (board 73).
enum PricesByCountryFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case suggested
    case setByYou
    case automatic

    var id: String { rawValue }

    /// The segment's name, before its count.
    var title: String {
        switch self {
        case .all: String(localized: "All", comment: "kind:segment")
        case .suggested: String(localized: "Suggested", comment: "kind:segment")
        case .setByYou: String(localized: "Set by You", comment: "kind:segment")
        case .automatic: String(localized: "Automatic", comment: "kind:segment")
        }
    }
}
