//
//  PricingProductFactsReading.swift
//  Atlas
//

import Foundation

/// Reads what a product's Details tab shows beyond the catalog
/// (`PricingProductFactsReader` over the push's transport); DEBUG scenes
/// and tests use canned answers.
@MainActor
protocol PricingProductFactsReading {
    func facts(for product: PricingProduct) async throws -> PricingProductFacts
}
