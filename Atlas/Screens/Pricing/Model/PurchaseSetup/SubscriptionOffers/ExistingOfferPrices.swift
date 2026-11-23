//
//  ExistingOfferPrices.swift
//  Atlas
//

import Foundation

/// Where an offer App Store Connect has runs, and what it costs in the
/// United States: read from its `prices` with their price points
/// (`SubscriptionOfferResource.pricesPath`).
struct ExistingOfferPrices: Hashable, Sendable {
    /// Alpha-3, sorted.
    var territoryIDs: [String] = []
    /// Nil for a free offer, or one that doesn't run there.
    var usPrice: Decimal?
    /// Each territory's price, when it has one.
    var customerPrices: [String: Decimal] = [:]

    init(territoryIDs: [String] = [], usPrice: Decimal? = nil, customerPrices: [String: Decimal] = [:]) {
        self.territoryIDs = territoryIDs
        self.usPrice = usPrice
        self.customerPrices = customerPrices
    }

    /// From one read's `data` (the prices) and `included` (their points).
    init(data: [[String: Any]], included: [[String: Any]]) {
        let points = Dictionary(included.compactMap { point in
            (point["id"] as? String).flatMap { id in PushPagedRead.customerPrice(of: point).map { (id, $0) } }
        }, uniquingKeysWith: { first, _ in first })
        var prices: [String: Decimal] = [:]
        var territories: Set<String> = []
        for price in data {
            guard let territory = PushPagedRead.relationshipID("territory", of: price) else { continue }
            territories.insert(territory)
            if let point = PushPagedRead.relationshipID("subscriptionPricePoint", of: price), let amount = points[point] {
                prices[territory] = amount
            }
        }
        territoryIDs = territories.sorted()
        customerPrices = prices
        usPrice = prices[NewSubscription.baseTerritoryID]
    }

    /// "175 countries or regions".
    var territoriesTitle: String {
        String(localized: "\(territoryIDs.count) countries or regions")
    }
}
