//
//  CountingFactsReader.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Counts the product page's facts reads, answering 175 countries and
/// regions and Family Sharing off.
@MainActor
final class CountingFactsReader: PricingProductFactsReading {
    private(set) var count = 0

    func facts(for _: PricingProduct) async throws -> PricingProductFacts {
        count += 1
        return PricingProductFacts(availableTerritoryCount: 175, availableInNewTerritories: true, isFamilySharable: false)
    }
}
