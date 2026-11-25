//
//  PricingProductFacts.swift
//  Atlas
//

import Foundation

/// What a product's Details tab shows beyond the catalog, as App Store
/// Connect answers it (`PricingProductFactsReader`): where it's sold and
/// whether Family Sharing is on. Nil where Apple's answer didn't say.
struct PricingProductFacts: Hashable, Sendable {
    /// Countries and regions it's available in.
    var availableTerritoryCount: Int?
    /// Whether it becomes available in countries Apple adds later.
    var availableInNewTerritories: Bool?
    var isFamilySharable: Bool?
}
