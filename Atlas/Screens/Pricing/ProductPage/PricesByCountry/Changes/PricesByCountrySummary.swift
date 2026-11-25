//
//  PricesByCountrySummary.swift
//  Atlas
//

import Foundation

/// The line under a product's row in Review & Push: "Brazil R$ 199,90,
/// Japan back to automatic. Applies when you push." The first few countries
/// by name, then how many more.
enum PricesByCountrySummary {
    struct Item: Hashable, Sendable {
        var name: String
        var isAutomatic: Bool
        /// The new price, as the territory writes it.
        var price: String
    }

    /// How many countries the line names before "and N more".
    static let listedCount = 3

    static func text(_ items: [Item]) -> String {
        let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var parts = sorted.prefix(listedCount).map(part)
        let more = sorted.count - listedCount
        if more > 0 {
            parts.append(String(localized: "and \(more) more", comment: "kind:label"))
        }
        let list = parts.joined(separator: ", ")
        return String(localized: "\(list). Applies when you push.", comment: "kind:label")
    }

    private static func part(_ item: Item) -> String {
        item.isAutomatic
            ? String(localized: "\(item.name) back to automatic", comment: "kind:label")
            : "\(item.name) \(item.price)"
    }
}
