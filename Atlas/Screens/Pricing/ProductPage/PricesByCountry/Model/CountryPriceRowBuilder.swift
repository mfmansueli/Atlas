//
//  CountryPriceRowBuilder.swift
//  Atlas
//

import Foundation

/// Turns a product's price matrix rows into Prices by Country rows: how
/// each country's price is set, what waits in Review & Push, the open
/// suggestion of a country nobody dismissed, and what that suggestion is
/// based on.
struct CountryPriceRowBuilder {
    let product: PricingProduct
    let sheet: ProductPriceSheet
    let rows: [PricingRow]
    /// The product's price suggestion is open (not dismissed, not Keep my
    /// prices, not an in-app purchase).
    var showsSuggestions: Bool
    /// The strategy suggests prices for this product at all (not Keep my
    /// prices, not an in-app purchase), open or already accepted.
    var knowsSuggestions = true
    var dismissedTerritoryIDs: Set<String> = []
    /// An in-app purchase's queued prices (`InAppPurchaseCountryPrices`);
    /// a subscription's come with its matrix rows.
    var inAppPurchaseQueued: [String: QueuedCountryPrice] = [:]
    /// Countries in a running price test or its comparison (board 76).
    var priceTestNotes: [String: CountryPriceTestNote] = [:]
    var territories = TerritoryCatalog.standard

    func build() -> [CountryPriceRow] {
        rows.compactMap(row)
    }

    func row(_ row: PricingRow) -> CountryPriceRow? {
        guard let price = sheet.prices[row.id] else { return nil }
        let queued = product.isInAppPurchase ? inAppPurchaseQueued[row.id] : subscriptionQueued(row, automatic: price.equalized)
        let showsSuggestion = showsSuggestions && !row.isBase && queued == nil && row.hasSuggestion
            && !dismissedTerritoryIDs.contains(row.id)
        let knowsSuggestion = knowsSuggestions && !product.isInAppPurchase && !row.isBase && row.hasSuggestion
        return CountryPriceRow(
            territory: row.territory,
            current: row.current,
            automatic: price.equalized,
            isBase: row.isBase,
            isInAppPurchase: product.isInAppPurchase,
            followsAppleToday: !row.isBase && followsApple(row),
            queued: queued,
            suggestion: showsSuggestion ? row.target : nil,
            suggested: knowsSuggestion ? row.target : nil,
            proceeds: proceeds(row, queued: queued),
            feelsLike: feelsLike(row),
            provenance: row.calculation.provenance,
            factor: row.recommendation?.factor ?? row.calculation.factor,
            reason: row.isBase ? nil : row.recommendation?.reason,
            confidence: row.recommendation?.confidence,
            likelyHeldBack: knowsSuggestions && row.likelyHeldBack,
            pageViews: row.pageViews,
            howSureReason: row.isBase ? nil : row.recommendation?.howSureReason,
            evidence: row.isBase ? nil : row.recommendation?.evidence,
            priceTest: row.isBase ? nil : priceTestNotes[row.id]
        )
    }

    /// An in-app purchase follows Apple where it has no hand-set price; a
    /// subscription where today's price is the equalized one.
    private func followsApple(_ row: PricingRow) -> Bool {
        if product.isInAppPurchase, let manual = sheet.manualTerritoryIDs { return !manual.contains(row.id) }
        return !row.isCustomPrice
    }

    /// A subscription's queued price; at the equalized price it's Apple's
    /// automatic one, whoever queued it.
    private func subscriptionQueued(_ row: PricingRow, automatic: PricePoint) -> QueuedCountryPrice? {
        guard let queued = row.queued, PricingRow.differs(queued.price, row.current.customerPrice) else { return nil }
        let isAutomatic = !row.isBase && !PricingRow.differs(queued.price, automatic.customerPrice)
        return QueuedCountryPrice(price: queued.price, isAutomatic: isAutomatic, source: queued.source)
    }

    /// The shown price's proceeds: today's point's (Apple's, read with the
    /// price), or the queued price's point when Apple's points for the
    /// country are here; never a simulated point's estimate.
    private func proceeds(_ row: PricingRow, queued: QueuedCountryPrice?) -> Decimal? {
        guard let queued else { return row.current.proceeds }
        guard sheet.hasRealGrid(row.id) else { return nil }
        return sheet.ladders[row.id]?.point(at: queued.price)?.proceeds
    }

    private func feelsLike(_ row: PricingRow) -> CountryFeelsLike? {
        let factor = row.recommendation?.factor ?? row.calculation.factor
        guard factor > 0, row.equalizationMultiplier > 0 else { return nil }
        return CountryFeelsLike(
            multiplier: row.equalizationMultiplier,
            factor: row.isBase ? 1 : factor,
            basePrice: sheet.basePrice,
            baseCurrency: territories.territory(alpha3: sheet.baseTerritoryID)?.currencyCode ?? "USD"
        )
    }
}
