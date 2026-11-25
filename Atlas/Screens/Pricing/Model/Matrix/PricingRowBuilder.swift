//
//  PricingRowBuilder.swift
//  Atlas
//

import Foundation

/// Turns a product's price sheet and the strategy into matrix rows: one per
/// territory the product is sold in, with its suggestion and strategy price.
/// Suggestions depend only on the sheet, so callers keep them while the
/// strategy changes and only the strategy prices are worked out again.
///
/// No territory suggests a price on a simulated ladder: only where Apple's
/// own points are here (`ProductPriceSheet.hasRealGrid`), and only once the
/// product's read of them finished (`isGridReady`), so counts don't grow
/// as batches land.
struct PricingRowBuilder {
    let catalog: TerritoryCatalog
    let calculator: PriceCalculator
    let sheet: ProductPriceSheet
    let strategy: PricingStrategy
    let showsSuggestions: Bool
    /// The push has a start date (`PriceSchedule`).
    var isScheduled = false
    /// The product's Apple price points have been read (`PriceGridState`).
    var isGridReady = true
    /// Suggests only on Apple's own points. A subscription that doesn't
    /// exist yet has none to read (`NewSubscriptionRecommendation`).
    var requiresRealGrid = true
    /// A new base price waiting in Review & Push. Suggestions and strategy
    /// prices are worked out from it, so accepting them fits the price about
    /// to be pushed (Alba, 25 Nov 2026: US$ 4.99 → 6.19 waiting, while 47
    /// suggestions still stood on US$ 4.99). Apple's equalized prices scale
    /// with it: equalization is proportional to the base point, give or take
    /// one point of rounding.
    var queuedBasePrice: Decimal?

    func rows(queued: [String: QueuedPrice] = [:]) -> [PricingRow] {
        var builder = self
        builder.queuedBasePrice = queuedBasePrice ?? queued[sheet.baseTerritoryID]?.price
        return builder.rows(recommendations: builder.recommendations(), queued: queued)
    }

    /// The base price suggestions start from: the one waiting to be pushed,
    /// else today's.
    var effectiveBasePrice: Decimal {
        guard let queuedBasePrice, queuedBasePrice > 0, sheet.basePrice > 0 else { return sheet.basePrice }
        return queuedBasePrice
    }

    /// The suggestion per territory, or none while Pricing keeps your prices.
    func recommendations() -> [String: Recommendation] {
        guard showsSuggestions else { return [:] }
        let recommender = PriceRecommender(calculator: calculator, baseTerritoryID: sheet.baseTerritoryID)
        let pooling = sheet.sales.pooling(in: catalog)
        var result: [String: Recommendation] = [:]
        for territory in catalog.territories where suggests(in: territory.id) {
            guard let input = input(for: territory) else { continue }
            let evidence = sheet.sales.evidence(for: territory.id, pooling: pooling, hasRealGrid: sheet.hasRealGrid(territory.id))
            result[territory.id] = recommender.recommend(input, evidence: evidence)
        }
        return result
    }

    func rows(recommendations: [String: Recommendation], queued: [String: QueuedPrice]) -> [PricingRow] {
        var effective = strategy
        effective.baseTerritoryID = sheet.baseTerritoryID
        return catalog.territories.compactMap { territory in
            guard let price = sheet.prices[territory.id], let input = input(for: territory) else { return nil }
            return PricingRow(
                territory: territory,
                current: price.current,
                equalized: price.equalized.customerPrice,
                equalizationMultiplier: price.equalizationMultiplier,
                isBase: territory.id == sheet.baseTerritoryID,
                recommendation: recommendations[territory.id],
                calculation: calculator.calculate(input, strategy: effective),
                usesCustomStrategy: strategy.isCustom,
                pageViews: sheet.sales.pageViews(in: territory.id),
                queued: queued[territory.id],
                isScheduled: isScheduled,
                hasRealGrid: suggests(in: territory.id)
            )
        }
    }

    /// Whether the territory may suggest a price: on Apple's own points.
    func suggests(in territoryID: String) -> Bool {
        guard requiresRealGrid else { return true }
        return isGridReady && sheet.hasRealGrid(territoryID)
    }

    func input(for territory: Territory) -> PriceCalculationInput? {
        guard let price = sheet.prices[territory.id] else { return nil }
        let scale = sheet.basePrice > 0 ? effectiveBasePrice / sheet.basePrice : 1
        var input = PriceCalculationInput(
            territory: territory,
            basePrice: effectiveBasePrice,
            equalizedPrice: price.equalized.customerPrice * scale,
            ladder: sheet.ladder(for: territory, commission: calculator.commission),
            currentPrice: price.current.customerPrice,
            equalizationMultiplier: price.equalizationMultiplier
        )
        input.hasRealLadder = sheet.hasRealGrid(territory.id)
        return input
    }
}
