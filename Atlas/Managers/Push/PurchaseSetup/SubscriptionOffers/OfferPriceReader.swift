//
//  OfferPriceReader.swift
//  Atlas
//

import Foundation

/// Reads, while pushing, each territory's price point for an offer: where
/// the subscription is sold (its availability) unless territories were
/// chosen, the US price point at the offer's price and the points Apple
/// equalizes with it, and for a territory priced apart its own point at
/// that price. A free offer has no points: each territory is listed alone.
/// The same reads an introductory offer makes (`IntroductoryOfferEverywhere`).
struct OfferPriceReader: Hashable, Sendable {
    var plan: OfferPricesPlan

    /// One territory's price: the territory and, for a paid offer, its point.
    struct Price: Hashable, Sendable {
        var territoryID: String
        var pricePointID: String?
    }

    /// `GET` the subscription's availability.
    var availabilityPath: String {
        "/v1/subscriptions/\(plan.subscriptionID)/subscriptionAvailability?fields%5BsubscriptionAvailabilities%5D=availableInNewTerritories"
    }

    /// `GET` the subscription's price points in a territory.
    func pricePointsPath(territoryID: String) -> String {
        "/v1/subscriptions/\(plan.subscriptionID)/pricePoints?filter%5Bterritory%5D=\(territoryID)"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"
    }

    /// Every territory's price, the United States first when it's one.
    @MainActor
    func prices(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [Price] {
        let territories = try await territoryIDs(via: transport, note: note)
        guard let usPrice = plan.usPrice else {
            return territories.map { Price(territoryID: $0, pricePointID: nil) }
        }
        var points = try await equalizedPoints(at: usPrice, for: territories, via: transport, note: note)
        for (territoryID, price) in plan.territoryPrices.sorted(by: { $0.key < $1.key }) where territories.contains(territoryID) {
            points[territoryID] = try await point(at: price, in: territoryID, via: transport, note: note)
        }
        let priced = territories.filter { points[$0] != nil }
        guard !priced.isEmpty else { throw SubscriptionOfferPushError.noTerritories }
        return priced.map { Price(territoryID: $0, pricePointID: points[$0]) }
    }

    /// The chosen territories (the United States first), or where the
    /// subscription is available.
    @MainActor
    private func territoryIDs(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [String] {
        if let chosen = plan.territoryIDs {
            let base = NewSubscription.baseTerritoryID
            return chosen.contains(base) ? [base] + chosen.filter { $0 != base } : chosen
        }
        let availability: AppStoreConnectResponse
        do {
            availability = try await transport.fetch(availabilityPath)
        } catch AppStoreConnectError.notFound {
            throw SubscriptionOfferPushError.notAvailable
        }
        note(availability.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: availability.data) as? [String: Any]
        guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw SubscriptionOfferPushError.notAvailable }
        let ids = try await PushPagedRead.resources(at: IntroductoryOfferEverywhere.availableTerritoriesPath(availabilityID: id), via: transport, note: note)
            .data.compactMap { $0["id"] as? String }
        guard !ids.isEmpty else { throw SubscriptionOfferPushError.notAvailable }
        return ids
    }

    /// The US point at `price` and the ones Apple equalizes with it.
    @MainActor
    private func equalizedPoints(
        at price: Decimal,
        for territories: [String],
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [String: String] {
        let base = NewSubscription.baseTerritoryID
        let baseID = try await point(at: price, in: base, via: transport, note: note)
        var points = [base: baseID]
        guard territories.contains(where: { $0 != base && plan.territoryPrices[$0] == nil }) else { return points }
        let equalized = try await PushPagedRead.resources(
            at: IntroductoryOfferEverywhere.equalizationsPath(pricePointID: baseID), via: transport, note: note
        ).data
        for point in equalized {
            guard let territory = PushPagedRead.relationshipID("territory", of: point), let id = point["id"] as? String else { continue }
            points[territory] = points[territory] ?? id
        }
        return points
    }

    /// The territory's price point at exactly `price`.
    @MainActor
    private func point(
        at price: Decimal, in territoryID: String, via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        let points = try await PushPagedRead.resources(at: pricePointsPath(territoryID: territoryID), via: transport, note: note).data
        guard let id = points.first(where: { PushPagedRead.customerPrice(of: $0) == price })?["id"] as? String else {
            throw SubscriptionOfferPushError.noPricePoint(territoryID: territoryID, price: price, nearest: PushPagedRead.nearest(price, in: points))
        }
        return id
    }
}
