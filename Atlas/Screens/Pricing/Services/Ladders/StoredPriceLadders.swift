//
//  StoredPriceLadders.swift
//  Atlas
//

import Foundation

/// One product's Apple price point ladders as `PriceLadderDiskStore`
/// keeps them, by commission and territory, each with the day it was
/// fetched. Amounts are kept as the decimal text Apple sends ("9.99"),
/// so nothing goes through `Double` on the way back.
struct StoredPriceLadders: Codable, Equatable, Sendable {
    /// One territory's ladder and when it was read.
    struct Ladder: Codable, Equatable, Sendable {
        var fetchedAt: Date
        var currencyCode: String
        /// [customer price, proceeds, price point ID]: compact, since a
        /// territory has about 800 points.
        var points: [[String]]
    }

    /// Files of another version are read as empty and fetched again.
    static let currentVersion = 1

    var version = Self.currentVersion
    var productID: String
    /// By `Commission.rawValue`, then territory (alpha-3).
    var ladders: [String: [String: Ladder]] = [:]

    var isEmpty: Bool { ladders.values.allSatisfy(\.isEmpty) }

    // MARK: - Converting

    static func ladder(_ ladder: PricePointLadder, fetchedAt: Date) -> Ladder {
        Ladder(
            fetchedAt: fetchedAt,
            currencyCode: ladder.currencyCode,
            points: ladder.points.map { point in
                [text(point.customerPrice), text(point.proceeds)] + (point.appStoreConnectID.map { [$0] } ?? [])
            }
        )
    }

    static func pricePointLadder(_ stored: Ladder, territoryID: String) -> PricePointLadder {
        let points = stored.points.compactMap { values -> PricePoint? in
            guard values.count >= 2, let price = decimal(values[0]), let proceeds = decimal(values[1]) else { return nil }
            return PricePoint(customerPrice: price, proceeds: proceeds, appStoreConnectID: values.count > 2 ? values[2] : nil)
        }
        return PricePointLadder(territoryID: territoryID, currencyCode: stored.currencyCode, points: points)
    }

    private static let posix = Locale(identifier: "en_US_POSIX")

    private static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: posix)
    }

    private static func decimal(_ text: String) -> Decimal? {
        Decimal(string: text, locale: posix)
    }
}
