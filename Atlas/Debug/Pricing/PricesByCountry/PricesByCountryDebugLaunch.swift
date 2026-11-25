//
//  PricesByCountryDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a Prices by Country DEBUG scene opens with (board 73, `pr-prod-*`),
/// set through the page's own state once the product's prices are read.
struct PricesByCountryDebugLaunch {
    /// Opens this country's price popover (alpha-3).
    var popoverTerritory: String?
    /// The map colours suggested prices.
    var mapShowsSuggested = false
    /// Opens the Filters popover.
    var opensFilters = false
    /// Columns shown besides the default ones.
    var shownColumns: [PricesByCountryColumn] = []
    /// Opens Accept All N….
    var opensAcceptAll = false
    /// Sorts by change, the biggest rise first.
    var sortsByRise = false
    /// Accepts this country's suggestion stepped one price point up
    /// (alpha-3): How it's set reads Adjusted suggestion.
    var adjustedTerritory: String?
}
#endif
