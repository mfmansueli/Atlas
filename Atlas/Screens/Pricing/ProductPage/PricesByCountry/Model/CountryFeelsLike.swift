//
//  CountryFeelsLike.swift
//  Atlas
//

import Foundation

/// How a price in one country feels for local incomes, in the base
/// country's money (README-Redesign, board 73): the price over Apple's
/// equalization multiplier (exchange rate and tax) over the purchasing-power
/// factor. Its ratio to the base price is the map's `PriceLevel` and the
/// Feels Like column's "2.1×".
struct CountryFeelsLike: Hashable, Sendable {
    /// Local currency per unit of base price, as Apple equalizes.
    var multiplier: Decimal
    /// The purchasing-power factor (World Bank, IMF, region median).
    var factor: Decimal
    /// The base country's price, in its currency.
    var basePrice: Decimal
    /// The base country's currency (USD for the United States).
    var baseCurrency: String

    /// The price for local incomes, in the base currency; nil without a
    /// multiplier or factor.
    func value(_ price: Decimal) -> Decimal? {
        guard multiplier > 0, factor > 0 else { return nil }
        return price / multiplier / factor
    }

    /// The value over the base price: 1.0 feels like the base price does.
    func ratio(_ price: Decimal) -> Double? {
        guard basePrice > 0, let value = value(price) else { return nil }
        return (value / basePrice).doubleValue
    }

    /// The map's colour step.
    func level(_ price: Decimal) -> PriceLevel? {
        ratio(price).map(PriceLevel.init(ratio:))
    }

    /// "$83", in whole base-currency units.
    func valueText(_ price: Decimal) -> String {
        value(price).map { CurrencyFormat.forCurrency(baseCurrency).formatWhole($0) } ?? "—"
    }

    /// "2.1×".
    func ratioText(_ price: Decimal) -> String {
        guard basePrice > 0, let value = value(price) else { return "—" }
        return PricingText.ratio(value / basePrice)
    }
}
