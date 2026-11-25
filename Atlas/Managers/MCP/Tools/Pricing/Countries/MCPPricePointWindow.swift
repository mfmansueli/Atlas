//
//  MCPPricePointWindow.swift
//  Atlas
//

import Foundation

/// Which of a territory's price points `get_price_points` lists: those
/// around today's price, around `near` (the territory's currency) or
/// `nearUsd` (US dollars), or every one from `min` to `max`.
struct MCPPricePointWindow: Hashable, Sendable {
    var near: Decimal?
    var nearUSD: Decimal?
    var range: ClosedRange<Decimal>?

    init(near: Decimal? = nil, nearUSD: Decimal? = nil, range: ClosedRange<Decimal>? = nil) {
        self.near = near
        self.nearUSD = nearUSD
        self.range = range
    }

    init(_ arguments: MCPToolArguments) throws {
        near = try Self.price(arguments, "near")
        nearUSD = try Self.price(arguments, "nearUsd")
        let min = try Self.price(arguments, "min")
        let max = try Self.price(arguments, "max")
        switch (min, max) {
        case let (min?, max?):
            guard min <= max else { throw MCPToolError.invalidArgument(name: "max", expected: String(localized: "a price at or above min")) }
            range = min...max
        case (nil, nil):
            range = nil
        default:
            throw MCPToolError.invalidArgument(name: min == nil ? "min" : "max", expected: String(localized: "min and max together"))
        }
    }

    /// The points to list, lowest first.
    @MainActor
    func points(in ladder: PricePointLadder, current: Decimal, currency: String) -> [PricePoint] {
        if let range {
            return Array(ladder.points.filter { range.contains($0.customerPrice) }.prefix(GetPricePointsTool.rangeLimit))
        }
        let center = near ?? nearUSD.flatMap { Self.price(ofDollars: $0, currency: currency) } ?? current
        return GetPricePointsTool.points(in: ladder, around: center)
    }

    /// About `dollars` in the currency, from approximate rates, rounded to
    /// the currency's minor units (a division leaves 55.000…024).
    static func price(ofDollars dollars: Decimal, currency: String) -> Decimal? {
        guard let perDollar = ExchangeRates.approximate.dollars(1, currency: currency), perDollar > 0 else { return nil }
        return (dollars / perDollar).rounded(scale: CurrencyFormat.forCurrency(currency).decimals)
    }

    private static func price(_ arguments: MCPToolArguments, _ name: String) throws -> Decimal? {
        guard let value = arguments.values[name], !value.isNull else { return nil }
        guard let price = MCPPriceValue.decimal(from: value) else {
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: "a positive price, e.g. 109.9"))
        }
        return price
    }
}
