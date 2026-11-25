//
//  CountryPriceTestNote.swift
//  Atlas
//

import Foundation

/// A country in a running price test, or in the region it's compared
/// with (board 76): How it's set reads "Price test · until Dec 23" and the
/// Change column the price before the test; a new price in the popover
/// warns first.
struct CountryPriceTestNote: Hashable, Sendable {
    enum Role: Hashable, Sendable {
        /// Its price is the test's until `endsOn`.
        case test
        /// Its price stays as it is: the test's comparison.
        case comparison
    }

    var role: Role
    var testID: PriceTest.ID
    /// "Europe", the test's region.
    var regionTitle: String
    /// The comparison region's name, "Asia Pacific".
    var comparisonTitle: String?
    /// Day 28, when the old prices come back.
    var endsOn: Date
    /// How many countries the test moves.
    var countryCount: Int
    /// The price before the test (a test country only).
    var oldPrice: Decimal?

    /// "Price test · until Dec 23".
    var sourceText: String {
        String(localized: "Price test · until \(PriceTestText.shortDate(endsOn))", comment: "kind:label")
    }

    /// The popover's warning before a new price.
    func popoverWarning(countryName: String) -> String {
        switch role {
        case .test:
            String(
                localized: """
                \(countryName) is in the \(regionTitle) price test until \(PriceTestText.shortDate(endsOn)). \
                A new price here ends the test in all \(countryCount) countries.
                """,
                comment: "kind:inline-warning"
            )
        case .comparison:
            String(
                localized: """
                \(countryName) is in \(comparisonTitle ?? ""), the comparison for the \(regionTitle) test. \
                A new price here makes the result less sure.
                """,
                comment: "kind:inline-warning"
            )
        }
    }
}
