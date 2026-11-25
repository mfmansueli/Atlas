//
//  CountryPriceEdit.swift
//  Atlas
//

import Foundation

/// What a person sets for one country in Prices by Country: Apple's
/// automatic price, or one of the territory's price points.
enum CountryPriceEdit: Hashable, Sendable {
    case automatic
    /// A customer price in the territory's currency; it lands on Apple's
    /// point at exactly that price.
    case price(Decimal)
}
