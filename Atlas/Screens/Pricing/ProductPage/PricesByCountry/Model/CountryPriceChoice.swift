//
//  CountryPriceChoice.swift
//  Atlas
//

import Foundation

/// The price popover's choice for one country (board 73, `pr-prod-why`):
/// the suggested price (stepped up or down over the country's price
/// points), Apple's automatic price, or a price point the person picks. It
/// opens on the suggestion when there is one, else on how the price is set
/// now. The base country has only its points.
struct CountryPriceChoice: Hashable, Sendable {
    enum Mode: Hashable, Sendable {
        case suggested
        case automatic
        case chosen
    }

    var territoryID: String
    var mode: Mode
    /// The picked point's customer price, used while `mode` is `.chosen`
    /// or `.suggested` (the stepped suggestion).
    var price: Decimal

    static func opening(_ row: CountryPriceRow) -> CountryPriceChoice {
        if let suggestion = row.suggestion {
            return CountryPriceChoice(territoryID: row.id, mode: .suggested, price: suggestion.customerPrice)
        }
        if row.source == .acceptedSuggestion || row.source == .adjustedSuggestion {
            return CountryPriceChoice(territoryID: row.id, mode: .suggested, price: row.shownPrice)
        }
        let mode: Mode = row.isBase || row.source != .automatic ? .chosen : .automatic
        return CountryPriceChoice(territoryID: row.id, mode: mode, price: row.shownPrice)
    }

    /// The base country has no automatic or suggested price: only its
    /// points. Without a suggestion, Suggested price can't be chosen.
    func effectiveMode(for row: CountryPriceRow) -> Mode {
        if row.isBase { return .chosen }
        if mode == .suggested, row.suggested == nil { return .chosen }
        return mode
    }

    /// The suggested price before any step.
    func suggestedPrice(for row: CountryPriceRow) -> Decimal? {
        row.suggested?.customerPrice
    }

    /// The suggestion was stepped to another point: "Adjusted from …".
    func isAdjusted(for row: CountryPriceRow) -> Bool {
        guard effectiveMode(for: row) == .suggested, let suggested = suggestedPrice(for: row) else { return false }
        return PricingRow.differs(price, suggested)
    }

    /// What the primary button sets, or nil when it would change nothing
    /// (it's then disabled). A subscription's automatic price is the
    /// equalized one, so choosing that same price changes nothing either.
    func edit(for row: CountryPriceRow) -> CountryPriceEdit? {
        switch effectiveMode(for: row) {
        case .automatic:
            return row.source == .automatic ? nil : .automatic
        case .suggested:
            let isSame = !PricingRow.differs(price, row.shownPrice)
            return isSame && row.isPending ? nil : .price(price)
        case .chosen:
            let isSame = !PricingRow.differs(price, row.shownPrice)
            if isSame, row.source != .automatic || !row.isInAppPurchase { return nil }
            return .price(price)
        }
    }

    /// Who the change is from: a suggestion (stepped or not) stays the
    /// suggestion's, so How it's set reads Accepted or Adjusted suggestion.
    func source(for row: CountryPriceRow) -> ChangeSource {
        effectiveMode(for: row) == .suggested ? .suggestion : .you
    }

    /// "Accept R$ 129,90", "Set R$ 199,90" or "Use Automatic Price".
    func primaryTitle(for row: CountryPriceRow) -> String {
        switch effectiveMode(for: row) {
        case .suggested: String(localized: "Accept \(row.currency.format(price))", comment: "kind:button")
        case .automatic: String(localized: "Use Automatic Price", comment: "kind:button")
        case .chosen: String(localized: "Set \(row.currency.format(price))", comment: "kind:button")
        }
    }

    /// One price point up (+1) or down (−1) from `price` among `points`
    /// (lowest first); nil at either end.
    static func step(_ price: Decimal, by offset: Int, in points: [PricePoint]) -> Decimal? {
        let prices = points.map(\.customerPrice)
        guard !prices.isEmpty else { return nil }
        let index: Int = if let exact = prices.firstIndex(where: { !PricingRow.differs($0, price) }) {
            exact + offset
        } else if offset > 0 {
            prices.firstIndex { $0 > price } ?? prices.count
        } else {
            (prices.lastIndex { $0 < price } ?? -1)
        }
        guard prices.indices.contains(index) else { return nil }
        return prices[index]
    }
}
