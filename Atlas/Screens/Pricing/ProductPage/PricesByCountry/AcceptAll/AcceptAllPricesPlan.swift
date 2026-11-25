//
//  AcceptAllPricesPlan.swift
//  Atlas
//

import Foundation

/// What Accept All N… is about to add (board 73, `pr-prod-acc`): how many
/// countries go down and how many go up, three of each as examples (the
/// biggest moves first).
struct AcceptAllPricesPlan: Hashable, Sendable {
    struct Example: Identifiable, Hashable, Sendable {
        var id: String
        var name: String
        /// "R$ 249,90 → R$ 129,90".
        var prices: String
        var change: PriceChange
    }

    static let exampleCount = 3

    var downCount: Int
    var upCount: Int
    var downExamples: [Example]
    var upExamples: [Example]

    init(rows: [CountryPriceRow]) {
        let moves = rows.compactMap { row -> (CountryPriceRow, PriceChange)? in
            guard let change = row.suggestionChange, change.direction != .none else { return nil }
            return (row, change)
        }
        let down = moves.filter { $0.1.direction == .decrease }.sorted { $0.1.percent < $1.1.percent }
        let rises = moves.filter { $0.1.direction == .increase }.sorted { $0.1.percent > $1.1.percent }
        downCount = down.count
        upCount = rises.count
        downExamples = down.prefix(Self.exampleCount).map(Self.example)
        upExamples = rises.prefix(Self.exampleCount).map(Self.example)
    }

    var count: Int { downCount + upCount }

    var hasIncreases: Bool { upCount > 0 }

    /// "104 go down".
    var downTitle: String {
        downCount == 1 ? String(localized: "1 goes down", comment: "kind:sheet-body") : String(localized: "\(downCount) go down", comment: "kind:sheet-body")
    }

    /// "8 go up".
    var upTitle: String {
        upCount == 1 ? String(localized: "1 goes up", comment: "kind:sheet-body") : String(localized: "\(upCount) go up", comment: "kind:sheet-body")
    }

    private static func example(_ move: (CountryPriceRow, PriceChange)) -> Example {
        let (row, change) = move
        return Example(
            id: row.id,
            name: row.territory.name,
            prices: "\(row.currency.format(change.old)) → \(row.currency.format(change.new))",
            change: change
        )
    }
}
