//
//  MCPPriceSheet+Countries.swift
//  Atlas
//

import Foundation

// A product's countries as Prices by Country shows them (board 73): how
// each price is set, what waits in Review & Push (an in-app purchase's
// schedule too) and the open suggestion of a country nobody dismissed.
extension MCPPriceSheet {
    /// The product's price suggestion is open: the app shows suggestions,
    /// the product is a subscription and nobody dismissed it on its card.
    var suggestionIsOpen: Bool {
        showsSuggestions && !workspace.pricingModes.isPriceSuggestionDismissed(productID: product.id, appID: app.id)
    }

    /// Every country's row, in catalog order, built like Prices by Country
    /// builds them.
    func countryRows() -> [CountryPriceRow] {
        CountryPriceRowBuilder(
            product: product,
            sheet: sheet,
            rows: rows(),
            showsSuggestions: suggestionIsOpen,
            dismissedTerritoryIDs: workspace.pricingModes.dismissedCountries(productID: product.id, appID: app.id),
            inAppPurchaseQueued: inAppPurchaseQueued()
        )
        .build()
    }

    /// The countries whose suggestion the person dismissed: every one when
    /// they dismissed the product's.
    var dismissedSuggestionTerritoryIDs: Set<String> {
        let modes = workspace.pricingModes
        if modes.isPriceSuggestionDismissed(productID: product.id, appID: app.id) { return Set(sheet.prices.keys) }
        return modes.dismissedCountries(productID: product.id, appID: app.id)
    }

    /// An in-app purchase's queued prices, by territory.
    func inAppPurchaseQueued() -> [String: QueuedCountryPrice] {
        guard product.isInAppPurchase,
              let change = workspace.changes.change(id: InAppPurchaseCountryPrices.changeID(productID: product.id))
        else { return [:] }
        return InAppPurchaseCountryPrices.queuedPrices(of: change, sheet: sheet)
    }
}
