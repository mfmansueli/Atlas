//
//  CountryPriceRow.swift
//  Atlas
//

import Foundation

/// One country or region in a product's Prices by Country table: today's
/// price, Apple's automatic one, what waits in Review & Push and the open
/// suggestion, with what the suggestion is based on (feels like, source,
/// factor, reason and how sure).
struct CountryPriceRow: Identifiable, Hashable, Sendable {
    var territory: Territory
    /// Today's price in App Store Connect.
    var current: PricePoint
    /// Apple's automatic price today: the base price equalized (the
    /// Equalized column).
    var automatic: PricePoint
    var isBase: Bool
    var isInAppPurchase: Bool
    /// Today's price is Apple's automatic one: an in-app purchase without a
    /// hand-set price here, or a subscription at its equalized price.
    var followsAppleToday: Bool
    var queued: QueuedCountryPrice?
    /// The open suggestion, shown in the row in the assistant's colour.
    var suggestion: PricePoint?
    /// The strategy's price for this country while suggestions show, open
    /// or not: the popover's "Suggested price", and what an accepted one
    /// is compared with ("Adjusted suggestion").
    var suggested: PricePoint?
    /// What the shown price earns after Apple's commission and tax, from
    /// its price point; nil when the point isn't known.
    var proceeds: Decimal?
    /// How a price feels for local incomes against the base price; nil
    /// without a factor.
    var feelsLike: CountryFeelsLike?
    /// Where the factor came from (World Bank, IMF, region median…).
    var provenance: PriceProvenance?
    /// The purchasing-power factor behind the suggestion.
    var factor: Decimal?
    /// One line of why: "Feels like 2.1× the US price".
    var reason: String?
    var confidence: RecommendationConfidence?
    /// The price likely holds people back (it feels at least 25% above the
    /// base price and the suggestion would change it).
    var likelyHeldBack = false

    var id: Territory.ID { territory.id }

    var currency: CurrencyFormat { CurrencyFormat.forCurrency(territory.currencyCode) }

    /// What the Price column shows: what waits, else today's price.
    var shownPrice: Decimal { queued?.price ?? current.customerPrice }

    var shownPriceText: String { currency.format(shownPrice) }

    var source: CountryPriceSource {
        if isBase { return .basePrice }
        if let queued {
            if queued.isAutomatic { return .automatic }
            guard queued.source == .suggestion else { return .setByYou }
            if let suggested, PricingRow.differs(suggested.customerPrice, queued.price) { return .adjustedSuggestion }
            return .acceptedSuggestion
        }
        return followsAppleToday ? .automatic : .setByYou
    }

    /// Waits in Review & Push: the "Not pushed" pill, "was …" and Undo.
    var isPending: Bool { queued != nil }

    var hasSuggestion: Bool { suggestion != nil }

    /// "was R$ 249,90", while a change waits.
    var wasText: String? {
        guard isPending else { return nil }
        return String(localized: "was \(currency.format(current.customerPrice))", comment: "kind:label")
    }

    /// The suggestion's move from today's price.
    var suggestionChange: PriceChange? {
        suggestion.map { PriceChange(old: current.customerPrice, new: $0.customerPrice) }
    }

    /// The queued move from today's price.
    var pendingChange: PriceChange? {
        queued.map { PriceChange(old: current.customerPrice, new: $0.price) }
    }

    /// What the Change column shows: the open suggestion, else what waits.
    var shownChange: PriceChange? {
        let change = suggestionChange ?? pendingChange
        return change?.direction == PriceChange.Direction.none ? nil : change
    }

    /// The factor came from a fallback, not the chosen index.
    var isFallback: Bool { provenance?.isFallback ?? false }

    // MARK: - Dollars

    /// About how many US dollars a price is, from bundled exchange rates.
    func dollars(_ price: Decimal) -> Decimal? {
        ExchangeRates.approximate.dollars(price, currency: territory.currencyCode)
    }

    /// "≈ $46" for the shown price.
    var dollarsText: String { Self.dollarsText(dollars(shownPrice)) }

    /// "≈ $39" for what the shown price earns; "—" without it.
    var proceedsText: String { Self.dollarsText(proceeds.flatMap(dollars)) }

    /// "≈ $46", "≈ $4.99" under ten dollars; "—" without a rate.
    static func dollarsText(_ dollars: Decimal?) -> String {
        guard let dollars else { return "—" }
        let amount = dollars < 10 ? CurrencyFormat.usd.format(dollars) : CurrencyFormat.usd.formatWhole(dollars)
        return String(localized: "≈ \(amount)", comment: "kind:label")
    }

    // MARK: - Sorting

    /// Country or region.
    var name: String { territory.name }

    var dollarsSortKey: Double { dollars(shownPrice)?.doubleValue ?? 0 }

    /// The shown price's feels-like ratio; rows without one go first.
    var feelsLikeSortKey: Double { feelsLike?.ratio(shownPrice) ?? 0 }

    /// The biggest drop first when ascending: the suggestion's ratio, else
    /// the queued one's; rows with neither go last.
    var changeSortKey: Double {
        let move = suggestionChange ?? pendingChange
        guard let move, move.old != 0 else { return Self.noChangeSortKey }
        return (move.new / move.old).doubleValue
    }

    static let noChangeSortKey = 1000.0

    // MARK: - Finding

    /// Matches "bra", "Brazil", "BR", "BRL" or "Americas".
    func matches(search text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [territory.name, territory.alpha2, territory.id, territory.currencyCode, territory.region.title]
            .contains { $0.localizedStandardContains(query) }
    }
}
