//
//  PricesByCountryChanges.swift
//  Atlas
//

import Foundation

/// How a product's changes from Prices by Country wait in Review & Push:
/// as one row per product ("Pricing · Lumen Plus Annual") with the line
/// "Brazil R$ 199,90, Japan back to automatic. Applies when you push." and
/// a field per country under it. A subscription's price changes stay one
/// `POST /v1/subscriptionPrices` per country (`PriceChangeFactory`), each
/// carrying the row; an in-app purchase's are one price schedule
/// (`InAppPurchaseCountryPrices`).
enum PricesByCountryChanges {
    static let creationPrefix = "pricesByCountry."

    /// Shared by every change of the product, so Review & Push shows one row.
    static func creationID(productID: String) -> String {
        "\(creationPrefix)\(productID)"
    }

    static func isFromPricesByCountry(_ change: PendingChange) -> Bool {
        change.creation?.id.hasPrefix(creationPrefix) == true
    }

    /// "Pricing · Lumen Plus Annual".
    static func rowTitle(_ product: PricingProduct) -> String {
        String(localized: "Pricing · \(product.name)", comment: "kind:title")
    }

    // MARK: - Fields

    private static let automaticSuffix = ".automatic"
    private static let priceSuffix = ".price"

    /// One country under the row: "Brazil", "R$ 249,90 → R$ 199,90", or
    /// "→ Apple’s automatic price · ¥1,200".
    static func field(
        territory: Territory,
        old: Decimal,
        new: Decimal,
        isAutomatic: Bool,
        source: ChangeSource
    ) -> PendingChangePart {
        let currency = CurrencyFormat.forCurrency(territory.currencyCode)
        let newValue = isAutomatic
            ? String(localized: "Apple’s automatic price · \(currency.format(new))", comment: "kind:label")
            : currency.format(new)
        return PendingChangePart(
            id: territory.id + (isAutomatic ? automaticSuffix : priceSuffix),
            title: territory.name,
            oldValue: currency.format(old),
            newValue: newValue,
            source: source
        )
    }

    /// The country (alpha-3) a field is about, and whether it goes back to
    /// Apple's automatic price.
    static func reading(_ field: PendingChangePart) -> (territoryID: String, isAutomatic: Bool)? {
        if field.id.hasSuffix(automaticSuffix) { return (String(field.id.dropLast(automaticSuffix.count)), true) }
        if field.id.hasSuffix(priceSuffix) { return (String(field.id.dropLast(priceSuffix.count)), false) }
        return nil
    }

    static func summaryItem(_ field: PendingChangePart) -> PricesByCountrySummary.Item? {
        guard let reading = reading(field) else { return nil }
        let price = reading.isAutomatic ? "" : field.newValue
        return PricesByCountrySummary.Item(name: field.title, isAutomatic: reading.isAutomatic, price: price)
    }

    // MARK: - Subscriptions

    /// A subscription's change for one country, as Review & Push's one row
    /// per product shows it. The line under the row is filled in by
    /// `refreshSummary`, once every country's change is queued.
    static func decorated(
        _ change: PendingChange,
        product: PricingProduct,
        territory: Territory,
        old: Decimal,
        new: Decimal,
        isAutomatic: Bool
    ) -> PendingChange {
        var change = change
        change.creation = PendingCreation(
            id: creationID(productID: product.id),
            title: rowTitle(product),
            detail: "",
            source: change.source,
            fields: [field(territory: territory, old: old, new: new, isAutomatic: isAutomatic, source: change.source)]
        )
        return change
    }

    /// Rewrites the line under the product's row on each of its changes, so
    /// whichever one Review & Push reads says every country.
    @MainActor
    static func refreshSummary(in queue: ChangeQueue, appID: StoreApp.ID, product: PricingProduct) {
        refreshSummary(in: queue, appID: appID, creationID: creationID(productID: product.id))
    }

    /// The same, by the row's creation id, for a change taken out of the
    /// queue without its product at hand (withdraw_changes).
    @MainActor
    static func refreshSummary(in queue: ChangeQueue, appID: StoreApp.ID, creationID id: String) {
        let owned = queue.changes(for: appID, section: .subscriptionPricing).filter { $0.creation?.id == id }
        guard !owned.isEmpty else { return }
        let items = owned.flatMap { $0.creation?.fields ?? [] }.compactMap(summaryItem)
        let detail = PricesByCountrySummary.text(items)
        let updated = owned.compactMap { change -> PendingChange? in
            guard change.creation?.detail != detail else { return nil }
            var change = change
            change.creation?.detail = detail
            return change
        }
        queue.upsert(contentsOf: updated)
    }
}
