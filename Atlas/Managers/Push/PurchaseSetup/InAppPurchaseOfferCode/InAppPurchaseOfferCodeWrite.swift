//
//  InAppPurchaseOfferCodeWrite.swift
//  Atlas
//

import Foundation

/// An in-app purchase's offer code created with its prices
/// (`POST /v1/inAppPurchaseOfferCodes`): its `name` and
/// `customerEligibilities`, the purchase, and one inline
/// `inAppPurchaseOfferPrices` per territory, `${price1}`…, each with its
/// territory and `pricePoint`. The queued request carries the attributes
/// and, under `atlas.offerPrices`, the plan the push reads the purchase's
/// points from (`OfferPriceReader`, owner `.inAppPurchase`).
///
/// A create first looks for an offer code of the purchase with the same
/// name, so a push that's tried again after Apple made it carries on with
/// that one instead of making a second.
struct InAppPurchaseOfferCodeWrite: Hashable, Sendable {
    var request: PushRequest
    var plan: OfferPricesPlan

    /// The step a queued change carries; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == InAppPurchaseOfferCodeResource.offerCodesPath,
              let body = PushPagedRead.body(of: request),
              let plan = OfferPricesPlan(body: body),
              case .inAppPurchase = plan.owner
        else { return nil }
        self.request = request
        self.plan = plan
    }

    /// The queued create: `attributes` and the purchase, with the plan.
    static func create(attributes: [String: Any], plan: OfferPricesPlan) -> PushRequest {
        let data: [String: Any] = [
            "type": InAppPurchaseOfferCodeResource.offerCodeType,
            "attributes": attributes,
            "relationships": ["inAppPurchase": ["data": ["type": "inAppPurchases", "id": plan.owner.id]]],
        ]
        let body: [String: Any] = ["data": data, OfferPricesPlan.metaKey: [OfferPricesPlan.planKey: plan.json]]
        return PushPagedRead.request(.post, InAppPurchaseOfferCodeResource.offerCodesPath, body)
    }

    /// `data.attributes`.
    var attributes: [String: Any] {
        ((PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any]) ?? [:]
    }

    /// Its name, which tells it from the purchase's other offer codes.
    var name: String? {
        attributes["name"] as? String
    }

    /// The request as Apple gets it, with one inline price per territory.
    func request(prices: [OfferPriceReader.Price]) -> PushRequest {
        guard var object = PushPagedRead.body(of: request), var data = object["data"] as? [String: Any] else { return request }
        object[OfferPricesPlan.metaKey] = nil
        let inline = plan.owner.inlinePrices(prices, type: InAppPurchaseOfferCodeResource.priceType)
        var relationships = data["relationships"] as? [String: Any] ?? [:]
        relationships["prices"] = ["data": inline.data]
        data["relationships"] = relationships
        object["data"] = data
        object["included"] = inline.included
        return PushPagedRead.request(.post, request.path, object)
    }

    /// Creates the offer code (or finds the one a push made before);
    /// returns its ID.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        if let found = try await existingID(via: transport, note: note) { return found }
        let prices = try await OfferPriceReader(plan: plan).prices(via: transport, note: note)
        let response = try await transport.send(request(prices: prices))
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw SubscriptionOfferPushError.notCreated }
        return id
    }

    /// The purchase's offer code with the same name, if it has one.
    @MainActor
    private func existingID(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String? {
        guard let name else { return nil }
        let path = InAppPurchaseOfferCodeResource.identitiesPath(purchaseID: plan.owner.id)
        let codes = try await PushPagedRead.resources(at: path, via: transport, note: note).data
        return codes.first { ($0["attributes"] as? [String: Any])?["name"] as? String == name }?["id"] as? String
    }
}
