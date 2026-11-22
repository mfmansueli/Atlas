//
//  AppCurrentPrice.swift
//  Atlas
//

import Foundation

/// The app's own price as its schedule has it today: the price in the base
/// territory (Apple equalizes every other one from it), and what a new
/// schedule would replace.
struct AppCurrentPrice: Hashable, Sendable {
    var scheduleID: String
    /// e.g. "USA".
    var baseTerritoryID: String
    var currencyCode: String
    /// Today's price in the base territory; nil when the schedule has none
    /// there today.
    var point: PricePoint?
    /// Other countries or regions whose price is set by hand today. A new
    /// schedule from Atlas gives them Apple's equalized price.
    var otherManualTerritoryIDs: [String] = []
    /// Price changes already scheduled after today, which a new schedule
    /// replaces.
    var laterChangeCount = 0

    var isFree: Bool { point.map { $0.customerPrice == 0 } ?? false }

    /// "Free", "$2.99"; "No price" without one today.
    var formattedPrice: String {
        guard let point else { return String(localized: "No price") }
        return AppPriceText.price(point.customerPrice, currencyCode: currencyCode)
    }

    /// Whether a new schedule would drop anything besides the base price.
    var replacesMoreThanThePrice: Bool {
        !otherManualTerritoryIDs.isEmpty || laterChangeCount > 0
    }
}
