//
//  DebugConfidencePricingServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// `DebugPricingServices` with one of HowSure's sample sales
/// (`DebugPricingConfidenceSales`) and an index snapshot taken as published.
/// Never contacts App Store Connect.
@MainActor
struct DebugConfidencePricingServices: PricingServices {
    let scenario: DebugPricingConfidenceSales.Scenario
    private let base: DebugPricingServices

    init(scenario: DebugPricingConfidenceSales.Scenario) {
        self.scenario = scenario
        base = DebugPricingServices()
    }

    func summary(for app: StoreApp) async throws -> PricingSummary {
        try await base.summary(for: app)
    }

    func catalog(for app: StoreApp) async throws -> PricingCatalog {
        try await base.catalog(for: app)
    }

    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        let sheet = try await base.priceSheet(for: product, commission: commission)
        return DebugPricingConfidenceSales.sheet(sheet, scenario: scenario, commission: commission)
    }

    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        try await base.ladders(for: product, territoryIDs: territoryIDs, commission: commission)
    }

    func indexSnapshot() -> PriceIndexSnapshot {
        DebugPricingConfidenceSales.snapshot
    }

    func offers(for product: PricingProduct) async throws -> [SubscriptionOffer] {
        try await base.offers(for: product)
    }

    func subscribers(for product: PricingProduct) async throws -> [String: Int]? {
        try await base.subscribers(for: product)
    }

    func salesComparison(for product: PricingProduct, territoryIDs: [String], changedOn date: Date) async throws -> [String: SalesComparison]? {
        try await base.salesComparison(for: product, territoryIDs: territoryIDs, changedOn: date)
    }
}
#endif
