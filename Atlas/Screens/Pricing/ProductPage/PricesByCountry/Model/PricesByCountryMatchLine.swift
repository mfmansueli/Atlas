//
//  PricesByCountryMatchLine.swift
//  Atlas
//

import Foundation

/// With no suggestion open, Prices by Country has no banner: a summary
/// line at the top says how many countries already match (README-DS §10),
/// in the secondary grey (board 76: blue is for what waits for you, and
/// zero suggestions wait for nothing).
enum PricesByCountryMatchLine {
    /// "Your prices match local purchasing power in 175 countries."; nil
    /// without any.
    static func text(count: Int) -> String? {
        switch count {
        case ...0: nil
        case 1: String(localized: "Your price matches local purchasing power in 1 country.", comment: "kind:description")
        default: String(localized: "Your prices match local purchasing power in \(count) countries.", comment: "kind:description")
        }
    }
}
