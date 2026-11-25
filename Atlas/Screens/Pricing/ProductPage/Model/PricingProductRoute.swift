//
//  PricingProductRoute.swift
//  Atlas
//

import Foundation

/// The product page open inside Pricing (board 73), in place of the
/// product cards: which product, which tab, and the Prices by Country
/// filter and country it opened on. `PricingViewModel.openProduct` makes
/// it, `closeProduct()` (the breadcrumb, ⌘[, Pricing in the sidebar)
/// clears it.
struct PricingProductRoute: Hashable, Sendable {
    var productID: PricingProduct.ID
    var tab: PricingProductTab = .pricesByCountry
    /// Show Countries opens on `.suggested`.
    var filter: PricesByCountryFilter = .all
    /// The country (alpha-3) Prices by Country selects and scrolls to, as
    /// Preview in asks; nil for none.
    var focusedTerritory: String?
}
