//
//  DebugPricingProductFactsReader.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: Lumen's products' availability and Family Sharing, as App
/// Store Connect would answer: every product in all 175 countries and
/// regions, Family Sharing on for Lumen Lifetime alone. `fails` makes
/// every read fail, as App Store Connect's server can.
struct DebugPricingProductFactsReader: PricingProductFactsReading {
    var fails = false

    func facts(for product: PricingProduct) async throws -> PricingProductFacts {
        if fails { throw AppStoreConnectError.server(statusCode: 503, detail: nil) }
        return PricingProductFacts(
            availableTerritoryCount: TerritoryCatalog.standard.count,
            availableInNewTerritories: true,
            isFamilySharable: product.id == DebugPricingCatalog.lumenLifetimeID
        )
    }
}
#endif
