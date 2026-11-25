//
//  PartialGridPricingServices.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// Lumen's DEBUG prices on simulated ladders, with Apple's points for every
/// territory but `missing`: a read that came back without them.
@MainActor
struct PartialGridPricingServices: PricingServices {
    var missing: Set<String>
    private let base = DebugPricingServices(simulatesGrid: true)

    init(missing: Set<String>) {
        self.missing = missing
    }

    func summary(for app: StoreApp) async throws -> PricingSummary {
        try await base.summary(for: app)
    }

    func catalog(for app: StoreApp) async throws -> PricingCatalog {
        try await base.catalog(for: app)
    }

    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        try await base.priceSheet(for: product, commission: commission)
    }

    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        try await base.ladders(for: product, territoryIDs: territoryIDs, commission: commission).filter { !missing.contains($0.key) }
    }

    func indexSnapshot() -> PriceIndexSnapshot {
        base.indexSnapshot()
    }
}
#endif
