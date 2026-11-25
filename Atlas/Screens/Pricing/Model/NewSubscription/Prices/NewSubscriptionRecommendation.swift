//
//  NewSubscriptionRecommendation.swift
//  Atlas
//

import Foundation

/// The prices a new subscription would get with the recommended prices:
/// each country's or region's equalized price for the US price, and what
/// the purchasing-power model Pricing's suggestions use gives instead
/// (`PricingRowBuilder`, the same strategy). Apple's equalization is
/// read from one of the app's subscriptions when it has one (its ratio
/// per country), else estimated from each currency's usual ratio; the
/// push snaps each price to the new subscription's own price points.
struct NewSubscriptionRecommendation: Hashable, Sendable {
    /// One country or region outside the base one.
    struct Place: Identifiable, Hashable, Sendable {
        var territory: Territory
        /// Apple's equalized price for the US price, in local currency.
        var equalized: Decimal
        var recommended: Decimal

        var id: String { territory.id }

        var currency: CurrencyFormat { CurrencyFormat.forCurrency(territory.currencyCode) }

        var isLower: Bool { recommended < equalized && PricingRow.differs(recommended, equalized) }
        var isHigher: Bool { recommended > equalized && PricingRow.differs(recommended, equalized) }
        var differs: Bool { isLower || isHigher }

        /// −0.25 for a quarter lower.
        var change: Decimal {
            equalized > 0 ? (recommended - equalized) / equalized : 0
        }

        /// "−25%".
        var changeText: String {
            change.doubleValue.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
        }
    }

    var basePrice: Decimal
    /// Every other country or region, in the catalog's order.
    var places: [Place]
    /// False when no subscription of the app had prices to read Apple's
    /// equalization from.
    var usesAppleRatios: Bool

    var changed: [Place] { places.filter(\.differs) }
    var lowerCount: Int { places.count(where: \.isLower) }
    var higherCount: Int { places.count(where: \.isHigher) }
    var equalizedCount: Int { places.count - changed.count }

    /// What the push sets, by alpha-3: only where it differs from Apple's.
    var prices: [String: Decimal] {
        Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0.recommended) })
    }

    /// "112 lower than Apple’s automatic price, none higher."
    var summary: String {
        let lower = lowerCount, higher = higherCount
        if lower == 0, higher == 0 {
            return String(localized: "The same as Apple’s automatic prices everywhere.", comment: "kind:hint")
        }
        let higherText = higher == 0
            ? String(localized: "none higher", comment: "kind:hint")
            : String(localized: "\(higher) higher", comment: "kind:hint")
        return String(localized: "\(lower) lower than Apple’s automatic price, \(higherText).", comment: "kind:hint")
    }

    /// The countries shown first: Brazil, India, Germany, Japan, Mexico.
    static let sampleIDs = ["BRA", "IND", "DEU", "JPN", "MEX"]

    /// "Brazil R$ 5,90 · India ₹69 · Germany 2,29 €".
    var samplesText: String {
        let shown = Self.sampleIDs.compactMap { id in changed.first { $0.id == id } }.prefix(3)
        let list = shown.isEmpty ? Array(changed.prefix(3)) : Array(shown)
        return list.map { "\($0.territory.name) \($0.currency.format($0.recommended))" }.joined(separator: " · ")
    }

    /// Works the prices out for `basePrice` in the United States.
    /// `reference` is one of the app's subscriptions' price sheets, for
    /// Apple's equalization ratios.
    static func make(
        basePrice: Decimal,
        reference: ProductPriceSheet?,
        calculator: PriceCalculator,
        strategy: PricingStrategy,
        catalog: TerritoryCatalog = .standard
    ) -> NewSubscriptionRecommendation? {
        guard basePrice > 0 else { return nil }
        let baseID = NewSubscription.baseTerritoryID
        let sheet = priceSheet(basePrice: basePrice, reference: reference, commission: calculator.commission, catalog: catalog)
        var effective = strategy
        effective.baseTerritoryID = baseID
        // A subscription that doesn't exist yet has no price points of its
        // own to read: its starting prices land on Apple's when it's pushed.
        var builder = PricingRowBuilder(catalog: catalog, calculator: calculator, sheet: sheet, strategy: effective, showsSuggestions: true)
        builder.requiresRealGrid = false
        let places = builder.rows().filter { !$0.isBase }.map { row in
            Place(territory: row.territory, equalized: row.equalized, recommended: row.target.customerPrice)
        }
        let usesAppleRatios = reference.map { !$0.prices.isEmpty } ?? false
        return NewSubscriptionRecommendation(basePrice: basePrice, places: places, usesAppleRatios: usesAppleRatios)
    }

    /// A sheet for a subscription that doesn't exist yet: today's price is
    /// the equalized one everywhere, on ladders around it.
    static func priceSheet(basePrice: Decimal, reference: ProductPriceSheet?, commission: Commission, catalog: TerritoryCatalog) -> ProductPriceSheet {
        let baseID = NewSubscription.baseTerritoryID
        let base = basePrice.doubleValue
        let range = max(0.29, base * 0.1)...max(base * 3, 1)
        var prices: [String: TerritoryPrice] = [:]
        var ladders: [String: PricePointLadder] = [:]
        for territory in catalog.territories {
            let multiplier: Decimal = if territory.id == baseID {
                1
            } else {
                reference?.prices[territory.id]?.equalizationMultiplier ?? PricingSampleData.equalizationMultiplier(currency: territory.currencyCode)
            }
            let ladder = SimulatedPriceLadder.make(territory: territory, equalizationMultiplier: multiplier, commission: commission, dollarRange: range)
            let target = basePrice * multiplier
            let basePoint = PricePoint(customerPrice: basePrice, proceeds: commission.proceeds(customerPrice: basePrice, taxRate: territory.taxRate))
            let point = territory.id == baseID
                ? ladder.point(at: basePrice) ?? basePoint
                : ladder.nearest(to: target, rounding: .auto) ?? PricePoint(customerPrice: target, proceeds: 0)
            prices[territory.id] = TerritoryPrice(territoryID: territory.id, current: point, equalized: point, equalizationMultiplier: multiplier)
            ladders[territory.id] = ladder
        }
        return ProductPriceSheet(productID: "new", baseTerritoryID: baseID, basePrice: basePrice, prices: prices, ladders: ladders)
    }
}
