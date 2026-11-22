//
//  FlakyPricingServices.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// Lumen Journal's sample prices (`DebugPricingServices`), except that a
/// product's price sheet fails its next reads with `error`, as App Store
/// Connect's 500 did on Atlas Pro Yearly right after its push.
@MainActor
final class FlakyPricingServices: PricingServices {
    private let base = DebugPricingServices()
    /// How many more reads of a product's prices fail, by product ID.
    var failures: [String: Int] = [:]
    var error: any Error = AppStoreConnectError.server(
        statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side."
    )
    /// Every price sheet asked for, by product ID, in order.
    private(set) var sheetRequests: [String] = []

    func summary(for app: StoreApp) async throws -> PricingSummary {
        try await base.summary(for: app)
    }

    func catalog(for app: StoreApp) async throws -> PricingCatalog {
        try await base.catalog(for: app)
    }

    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        sheetRequests.append(product.id)
        if let left = failures[product.id], left > 0 {
            failures[product.id] = left - 1
            throw error
        }
        return try await base.priceSheet(for: product, commission: commission)
    }

    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        try await base.ladders(for: product, territoryIDs: territoryIDs, commission: commission)
    }

    func indexSnapshot() -> PriceIndexSnapshot {
        base.indexSnapshot()
    }
}
#endif
