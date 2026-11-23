//
//  SubscriptionOfferWrite.swift
//  Atlas
//

import Foundation

/// A promotional offer, win-back offer or offer code created with its
/// prices (`POST /v1/subscriptionPromotionalOffers`, `/v1/winBackOffers`,
/// `/v1/subscriptionOfferCodes`), or a promotional offer's prices replaced
/// (`PATCH /v1/subscriptionPromotionalOffers/{id}`). App Store Connect takes
/// the prices inline: one `included` price per territory, `${price1}`…,
/// each with its territory and, for a paid offer, its price point. The
/// queued request carries the offer's attributes and, under
/// `atlas.offerPrices`, the plan the push reads the points from
/// (`OfferPriceReader`).
///
/// A create first looks for an offer of the subscription with the same
/// identity (`offerCode`, `offerId` or `name`), so a push that's tried
/// again after the offer was made carries on with that one.
struct SubscriptionOfferWrite: Hashable, Sendable {
    var request: PushRequest
    var resource: SubscriptionOfferResource
    var plan: OfferPricesPlan

    /// The step a queued change carries; nil for any other request.
    init?(_ request: PushRequest) {
        guard let resource = SubscriptionOfferResource(path: request.path),
              request.method == .post ? request.path == resource.path : request.method == .patch,
              let body = PushPagedRead.body(of: request),
              let plan = OfferPricesPlan(body: body)
        else { return nil }
        self.request = request
        self.resource = resource
        self.plan = plan
    }

    /// The queued create: `attributes` and the subscription, with the plan.
    static func create(_ resource: SubscriptionOfferResource, attributes: [String: Any], plan: OfferPricesPlan) -> PushRequest {
        let data: [String: Any] = [
            "type": resource.type,
            "attributes": attributes,
            "relationships": ["subscription": ["data": ["type": "subscriptions", "id": plan.subscriptionID]]],
        ]
        return PushPagedRead.request(.post, resource.path, ["data": data, OfferPricesPlan.metaKey: [OfferPricesPlan.planKey: plan.json]])
    }

    /// The queued `PATCH` that replaces an offer's prices.
    static func replacingPrices(_ resource: SubscriptionOfferResource, offerID: String, plan: OfferPricesPlan) -> PushRequest {
        let data: [String: Any] = ["type": resource.type, "id": offerID]
        return PushPagedRead.request(.patch, "\(resource.path)/\(offerID)", ["data": data, OfferPricesPlan.metaKey: [OfferPricesPlan.planKey: plan.json]])
    }

    var isCreate: Bool { request.method == .post }

    /// `data.attributes`.
    var attributes: [String: Any] {
        ((PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any]) ?? [:]
    }

    /// The value that tells it from the subscription's other offers.
    var identity: String? {
        attributes[resource.identityAttribute] as? String
    }

    /// The request as Apple gets it, with one inline price per territory.
    func request(prices: [OfferPriceReader.Price]) -> PushRequest {
        guard var object = PushPagedRead.body(of: request), var data = object["data"] as? [String: Any] else { return request }
        object[OfferPricesPlan.metaKey] = nil
        let inline = plan.owner.inlinePrices(prices, type: resource.priceType)
        var relationships = data["relationships"] as? [String: Any] ?? [:]
        relationships["prices"] = ["data": inline.data]
        data["relationships"] = relationships
        object["data"] = data
        object["included"] = inline.included
        return PushPagedRead.request(request.method, request.path, object)
    }

    /// Creates the offer (or finds the one a push made before) or replaces
    /// its prices; returns its ID.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        if isCreate, let found = try await existingID(via: transport, note: note) { return found }
        let prices = try await OfferPriceReader(plan: plan).prices(via: transport, note: note)
        let response = try await transport.send(request(prices: prices))
        note(response.rateLimit)
        guard isCreate else { return String(request.path.split(separator: "/").last ?? "") }
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw SubscriptionOfferPushError.notCreated }
        return id
    }

    /// The subscription's offer with the same identity, if it has one.
    @MainActor
    private func existingID(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String? {
        guard let identity else { return nil }
        let offers = try await PushPagedRead.resources(at: resource.identitiesPath(subscriptionID: plan.subscriptionID), via: transport, note: note).data
        return offers.first { ($0["attributes"] as? [String: Any])?[resource.identityAttribute] as? String == identity }?["id"] as? String
    }
}
