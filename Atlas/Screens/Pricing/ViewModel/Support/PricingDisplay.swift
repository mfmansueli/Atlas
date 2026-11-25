//
//  PricingDisplay.swift
//  Atlas
//

import Foundation

/// How Prices by Country shows a product's countries (board 73): the
/// table, a tile map coloured by how prices feel for local incomes, or a
/// histogram of prices in US dollars. Filters apply to all three.
enum PricingDisplay: String, CaseIterable, Hashable, Sendable {
    case table
    case map
    case histogram

    var title: String {
        switch self {
        case .table: String(localized: "Table", comment: "kind:segment")
        case .map: String(localized: "Map", comment: "kind:button")
        case .histogram: String(localized: "Histogram", comment: "kind:segment")
        }
    }

    var systemImage: String {
        switch self {
        case .table: "tablecells"
        case .map: "map"
        case .histogram: "chart.bar.xaxis"
        }
    }
}
