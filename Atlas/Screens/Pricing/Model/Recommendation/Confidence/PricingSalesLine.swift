//
//  PricingSalesLine.swift
//  Atlas
//

import Foundation

/// What the suggestions stand on, per sales state (README-DS §9): the
/// Prices by Country banner's second line and the "What it's based on" line.
enum PricingSalesLine {
    /// The banner's second line. `salesCountries`: countries with any start
    /// in 90 days; `borrowedCountries`: suggested countries that use their
    /// region's sales to be Fairly sure. When some do, one line says both
    /// (board 76): "Based on your sales in 12 countries · 9 use their
    /// region’s".
    static func banner(availability: PricingSalesData.Availability, salesCountries: Int, borrowedCountries: Int = 0) -> String {
        switch availability {
        case .available:
            if salesCountries == 0 { return noSalesYet }
            if borrowedCountries > 0 {
                return pooled(salesCountries: salesCountries, borrowedCountries: borrowedCountries)
            }
            return salesCountries == 1
                ? String(localized: "Based on your sales in 1 country and purchasing power.", comment: "kind:banner")
                : String(localized: "Based on your sales in \(salesCountries) countries and purchasing power.", comment: "kind:banner")
        case .noSalesYet:
            return noSalesYet
        case .roleCannotRead:
            return String(localized: "Purchasing power alone: this key’s role can’t read Sales and Trends.", comment: "kind:banner")
        case .turnedOff:
            return String(localized: "Purchasing power alone: sales data is off in Settings → Pricing.", comment: "kind:banner")
        case .notRead:
            return String(localized: "Purchasing power alone: Atlas hasn’t read your sales yet.", comment: "kind:banner")
        }
    }

    /// "What it's based on" when sales don't count; nil when they do.
    static func basis(_ availability: PricingSalesData.Availability) -> String? {
        switch availability {
        case .available: nil
        case .noSalesYet: String(localized: "Sales: none yet, so purchasing power alone", comment: "kind:description")
        case .roleCannotRead: PriceRecommender.cantReadSalesLine
        case .turnedOff: String(localized: "Sales: off in Settings → Pricing, so purchasing power alone", comment: "kind:description")
        case .notRead: String(localized: "Sales: not read yet, so purchasing power alone", comment: "kind:description")
        }
    }

    /// "Based on your sales in 12 countries · 9 use their region’s".
    private static func pooled(salesCountries: Int, borrowedCountries: Int) -> String {
        switch (salesCountries == 1, borrowedCountries == 1) {
        case (true, true):
            String(localized: "Based on your sales in 1 country · 1 uses its region’s", comment: "kind:banner")
        case (true, false):
            String(localized: "Based on your sales in 1 country · \(borrowedCountries) use their region’s", comment: "kind:banner")
        case (false, true):
            String(localized: "Based on your sales in \(salesCountries) countries · 1 uses its region’s", comment: "kind:banner")
        case (false, false):
            String(
                localized: "Based on your sales in \(salesCountries) countries · \(borrowedCountries) use their region’s",
                comment: "kind:banner"
            )
        }
    }

    private static var noSalesYet: String {
        String(localized: "No sales yet, so purchasing power alone.", comment: "kind:banner")
    }
}
