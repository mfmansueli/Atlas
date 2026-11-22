//
//  IntroductoryOfferEverywhere.swift
//  Atlas
//

import Foundation

/// A subscription's introductory offer in every territory it runs in.
/// App Store Connect keeps one `subscriptionIntroductoryOffers` resource per
/// territory, each `POST /v1/subscriptionIntroductoryOffers` with the
/// subscription, the territory and, for a paid offer, that territory's
/// price point. The queued request is one such `POST` whose territory is
/// `{introductoryOfferTerritories}`, with the chosen territories and the
/// US price under `atlas`; the subscription may be `{createdID:subscriptions}`
/// when the same change creates it.
///
/// The push reads where the subscription is sold (its availability) unless
/// territories were chosen, the US price point at the offer's price and
/// the points Apple equalizes with it, and the offers it has; then it
/// creates the offer in each territory that doesn't have one yet, so a
/// retry picks up where it stopped.
struct IntroductoryOfferEverywhere: Hashable, Sendable {
    var subscriptionID: String
    var offer: NewIntroductoryOffer

    static let path = "/v1/subscriptionIntroductoryOffers"
    static let placeholder = "{introductoryOfferTerritories}"
    static let metaKey = "atlas"

    init(subscriptionID: String, offer: NewIntroductoryOffer) {
        self.subscriptionID = subscriptionID
        self.offer = offer
    }

    /// The step a queued change carries; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let body = PushPagedRead.body(of: request),
              let data = body["data"] as? [String: Any],
              PushPagedRead.relationshipID("territory", of: data) == Self.placeholder,
              let subscriptionID = PushPagedRead.relationshipID("subscription", of: data),
              let attributes = data["attributes"] as? [String: Any],
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:))
        else { return nil }
        let meta = body[Self.metaKey] as? [String: Any] ?? [:]
        let price = (meta["priceUSD"] as? String).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
        let territories: IntroductoryOfferTerritories = (meta["territories"] as? [String]).map(IntroductoryOfferTerritories.chosen) ?? .everywhere
        self.subscriptionID = subscriptionID
        offer = NewIntroductoryOffer(
            mode: mode,
            duration: duration,
            numberOfPeriods: attributes["numberOfPeriods"] as? Int ?? 1,
            price: mode == .freeTrial ? nil : price,
            territories: territories,
            startDate: (attributes["startDate"] as? String).flatMap(NewIntroductoryOffer.day(from:)),
            endDate: (attributes["endDate"] as? String).flatMap(NewIntroductoryOffer.day(from:))
        )
    }

    /// The queued request.
    var request: PushRequest {
        var body = document(territoryID: Self.placeholder, pricePointID: nil)
        var meta: [String: Any] = [:]
        if let ids = offer.territories.chosenIDs { meta["territories"] = ids }
        if offer.mode != .freeTrial, let price = offer.price { meta["priceUSD"] = NSDecimalNumber(decimal: price).stringValue }
        body[Self.metaKey] = meta
        return PushPagedRead.request(.post, Self.path, body)
    }

    /// One territory's `POST`, as Apple gets it.
    func request(territoryID: String, pricePointID: String?) -> PushRequest {
        PushPagedRead.request(.post, Self.path, document(territoryID: territoryID, pricePointID: pricePointID))
    }

    private func document(territoryID: String, pricePointID: String?) -> [String: Any] {
        var attributes: [String: Any] = [
            "duration": offer.duration.rawValue,
            "offerMode": offer.mode.apiValue,
            "numberOfPeriods": offer.sentPeriods,
        ]
        if let start = offer.startDate { attributes["startDate"] = NewIntroductoryOffer.dayString(start) }
        if let end = offer.endDate { attributes["endDate"] = NewIntroductoryOffer.dayString(end) }
        var relationships: [String: Any] = [
            "subscription": ["data": ["type": "subscriptions", "id": subscriptionID]],
            "territory": ["data": ["type": "territories", "id": territoryID]],
        ]
        if let pricePointID {
            relationships["subscriptionPricePoint"] = ["data": ["type": "subscriptionPricePoints", "id": pricePointID]]
        }
        return ["data": ["type": "subscriptionIntroductoryOffers", "attributes": attributes, "relationships": relationships]]
    }

    // MARK: - Reads

    /// `GET` the subscription's availability.
    var availabilityPath: String {
        "/v1/subscriptions/\(subscriptionID)/subscriptionAvailability?fields%5BsubscriptionAvailabilities%5D=availableInNewTerritories"
    }

    /// `GET` an availability's territories.
    static func availableTerritoriesPath(availabilityID: String) -> String {
        "/v1/subscriptionAvailabilities/\(availabilityID)/availableTerritories?fields%5Bterritories%5D=currency&limit=200"
    }

    /// `GET` the subscription's price points in the United States.
    var pricePointsPath: String {
        "/v1/subscriptions/\(subscriptionID)/pricePoints?filter%5Bterritory%5D=\(NewSubscription.baseTerritoryID)"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"
    }

    /// `GET` the points Apple equalizes with the US one, with their territory.
    static func equalizationsPath(pricePointID: String) -> String {
        "/v1/subscriptionPricePoints/\(pricePointID)/equalizations?include=territory"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice,territory&fields%5Bterritories%5D=currency&limit=200"
    }

    /// `GET` the introductory offers the subscription has, with their territory.
    var offersPath: String {
        "/v1/subscriptions/\(subscriptionID)/introductoryOffers?include=territory"
            + "&fields%5BsubscriptionIntroductoryOffers%5D=territory&fields%5Bterritories%5D=currency&limit=200"
    }

    // MARK: - Sending

    /// Creates the offer in every territory it runs in that doesn't have one
    /// yet. `progress` gets (created, total) after each and `note` each
    /// response's rate limit.
    @MainActor
    func send(
        via transport: any PushTransport,
        progress: (Int, Int) -> Void,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        let territories = try await territoryIDs(via: transport, note: note)
        let points = try await pricePoints(for: territories, via: transport, note: note)
        let existing = try await Set(PushPagedRead.resources(at: offersPath, via: transport, note: note).data.compactMap {
            PushPagedRead.relationshipID("territory", of: $0)
        })
        let missing = territories.filter { !existing.contains($0) && (offer.mode == .freeTrial || points[$0] != nil) }
        guard !missing.isEmpty || !existing.isEmpty else { throw IntroductoryOfferPushError.noTerritories }
        for (index, territory) in missing.enumerated() {
            let response = try await transport.send(request(territoryID: territory, pricePointID: points[territory]))
            note(response.rateLimit)
            progress(index + 1, missing.count)
        }
    }

    /// The chosen territories, or where the subscription is available.
    @MainActor
    private func territoryIDs(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [String] {
        if let chosen = offer.territories.chosenIDs { return chosen }
        let availability: AppStoreConnectResponse
        do {
            availability = try await transport.fetch(availabilityPath)
        } catch AppStoreConnectError.notFound {
            throw IntroductoryOfferPushError.notAvailable
        }
        note(availability.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: availability.data) as? [String: Any]
        guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw IntroductoryOfferPushError.notAvailable }
        let ids = try await PushPagedRead.resources(at: Self.availableTerritoriesPath(availabilityID: id), via: transport, note: note)
            .data.compactMap { $0["id"] as? String }
        guard !ids.isEmpty else { throw IntroductoryOfferPushError.notAvailable }
        return ids
    }

    /// Each territory's price point for a paid offer: the US point at the
    /// offer's price and the ones Apple equalizes with it. Empty for a free
    /// trial.
    @MainActor
    private func pricePoints(
        for territories: [String],
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [String: String] {
        guard offer.mode != .freeTrial, let price = offer.price else { return [:] }
        let base = try await PushPagedRead.resources(at: pricePointsPath, via: transport, note: note).data
        guard let baseID = base.first(where: { PushPagedRead.customerPrice(of: $0) == price })?["id"] as? String else {
            throw IntroductoryOfferPushError.noPricePoint(price: price, nearest: PushPagedRead.nearest(price, in: base))
        }
        var points = [NewSubscription.baseTerritoryID: baseID]
        guard territories.contains(where: { $0 != NewSubscription.baseTerritoryID }) else { return points }
        let equalized = try await PushPagedRead.resources(at: Self.equalizationsPath(pricePointID: baseID), via: transport, note: note).data
        for point in equalized {
            guard let territory = PushPagedRead.relationshipID("territory", of: point), let id = point["id"] as? String else { continue }
            points[territory] = points[territory] ?? id
        }
        return points
    }
}
