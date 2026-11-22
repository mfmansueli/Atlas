//
//  InAppPurchaseAvailabilityEverywhere.swift
//  Atlas
//

import Foundation

/// A new in-app purchase's availability in every country or region: a
/// `POST /v1/inAppPurchaseAvailabilities` whose one territory is
/// `{everyTerritory}`, filled in with the territories App Store Connect has
/// (read once per push, like a new subscription's).
struct InAppPurchaseAvailabilityEverywhere: Hashable, Sendable {
    /// May be `{createdID:inAppPurchases}` until the push fills it in.
    var purchaseID: String
    var availableInNewTerritories: Bool

    static let path = "/v1/inAppPurchaseAvailabilities"

    static func request(purchaseID: String, availableInNewTerritories: Bool = true) -> PushRequest {
        InAppPurchaseAvailabilityEverywhere(purchaseID: purchaseID, availableInNewTerritories: availableInNewTerritories)
            .request(territoryIDs: [SubscriptionAvailabilityEverywhere.placeholder])
    }

    init(purchaseID: String, availableInNewTerritories: Bool) {
        self.purchaseID = purchaseID
        self.availableInNewTerritories = availableInNewTerritories
    }

    /// The request when it asks for every territory; nil for any other.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let object = PushPagedRead.body(of: request),
              let data = object["data"] as? [String: Any],
              let purchaseID = PushPagedRead.relationshipID("inAppPurchase", of: data),
              let territories = ((data["relationships"] as? [String: Any])?["availableTerritories"] as? [String: Any])?["data"] as? [[String: Any]],
              territories.compactMap({ $0["id"] as? String }) == [SubscriptionAvailabilityEverywhere.placeholder]
        else { return nil }
        self.purchaseID = purchaseID
        availableInNewTerritories = (data["attributes"] as? [String: Any])?["availableInNewTerritories"] as? Bool ?? true
    }

    /// The `POST` with these territories.
    func request(territoryIDs: [String]) -> PushRequest {
        PushPagedRead.request(.post, Self.path, [
            "data": [
                "type": "inAppPurchaseAvailabilities",
                "attributes": ["availableInNewTerritories": availableInNewTerritories],
                "relationships": [
                    "inAppPurchase": ["data": ["type": "inAppPurchases", "id": purchaseID]],
                    "availableTerritories": ["data": territoryIDs.map { ["type": "territories", "id": $0] }],
                ],
            ],
        ])
    }
}
