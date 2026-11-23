//
//  ExistingOfferPrices.swift
//  Atlas
//

import Foundation

/// Where an offer App Store Connect has runs, and what it costs in the
/// United States: read from its `prices` with their price points
/// (`SubscriptionOfferResource.pricesPath`). For a promotional offer, also
/// the territories priced apart: those whose price isn't the one Apple
/// equalizes with the US price point (read from its equalizations,
/// `SubscriptionOffersReader`), so new prices keep them.
struct ExistingOfferPrices: Hashable, Sendable {
    /// Alpha-3, sorted.
    var territoryIDs: [String] = []
    /// Nil for a free offer, or one that doesn't run there.
    var usPrice: Decimal?
    /// Each territory's price, when it has one.
    var customerPrices: [String: Decimal] = [:]
    /// The US price's point, when it has one: its equalizations tell the
    /// territories priced apart.
    var usPricePointID: String?
    /// Territories (alpha-3) whose price differs from the equalized one,
    /// with their own price; empty when none does or they weren't compared.
    var pricedApart: [String: Decimal] = [:]

    init(
        territoryIDs: [String] = [], usPrice: Decimal? = nil, customerPrices: [String: Decimal] = [:],
        pricedApart: [String: Decimal] = [:]
    ) {
        self.territoryIDs = territoryIDs
        self.usPrice = usPrice
        self.customerPrices = customerPrices
        self.pricedApart = pricedApart
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
                if territory == NewSubscription.baseTerritoryID { usPricePointID = point }
            }
        }
        territoryIDs = territories.sorted()
        customerPrices = prices
        usPrice = prices[NewSubscription.baseTerritoryID]
    }

    /// Sets `pricedApart` from the US point's equalizations (price points
    /// with their territory and customer price): every territory whose
    /// price isn't the equalized one, or that Apple doesn't equalize.
    mutating func comparePrices(withEqualized equalized: [[String: Any]]) {
        var equalizedPrices: [String: Decimal] = [:]
        for point in equalized {
            guard let territory = PushPagedRead.relationshipID("territory", of: point), let price = PushPagedRead.customerPrice(of: point) else {
                continue
            }
            equalizedPrices[territory] = equalizedPrices[territory] ?? price
        }
        pricedApart = customerPrices.filter { territory, price in
            territory != NewSubscription.baseTerritoryID && equalizedPrices[territory] != price
        }
    }

    /// "175 countries or regions".
    var territoriesTitle: String {
        String(localized: "\(territoryIDs.count) countries or regions")
    }
}
