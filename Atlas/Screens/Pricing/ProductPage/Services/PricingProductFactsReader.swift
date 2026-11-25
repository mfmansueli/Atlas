//
//  PricingProductFactsReader.swift
//  Atlas
//

import Foundation

/// Reads a product's availability and Family Sharing with the push's
/// transport (the API client), read-only: `GET /v1/subscriptions/{id}` or
/// `GET /v2/inAppPurchases/{id}` for `familySharable`, then its
/// availability (`OfferPriceOwner.availabilityPath`, the one offers are
/// priced from) and that availability's territories. A product with no
/// availability yet is available nowhere.
struct PricingProductFactsReader: PricingProductFactsReading {
    let transport: any PushTransport

    /// `GET` the product with its `familySharable` attribute alone.
    static func productPath(for product: PricingProduct) -> String {
        product.isInAppPurchase
            ? "/v2/inAppPurchases/\(product.id)?fields%5BinAppPurchases%5D=familySharable"
            : "/v1/subscriptions/\(product.id)?fields%5Bsubscriptions%5D=familySharable"
    }

    func facts(for product: PricingProduct) async throws -> PricingProductFacts {
        var facts = PricingProductFacts()
        let response = try await transport.fetch(Self.productPath(for: product))
        facts.isFamilySharable = Self.attributes(in: response.data)?["familySharable"] as? Bool
        let owner: OfferPriceOwner = product.isInAppPurchase ? .inAppPurchase(product.id) : .subscription(product.id)
        let availability: AppStoreConnectResponse
        do {
            availability = try await transport.fetch(owner.availabilityPath)
        } catch AppStoreConnectError.notFound {
            facts.availableTerritoryCount = 0
            return facts
        }
        let object = try? JSONSerialization.jsonObject(with: availability.data) as? [String: Any]
        guard let data = object?["data"] as? [String: Any], let id = data["id"] as? String else {
            facts.availableTerritoryCount = 0
            return facts
        }
        facts.availableInNewTerritories = (data["attributes"] as? [String: Any])?["availableInNewTerritories"] as? Bool
        let territories = try await PushPagedRead.resources(at: owner.availableTerritoriesPath(availabilityID: id), via: transport) { _ in }
        facts.availableTerritoryCount = territories.data.count
        return facts
    }

    private static func attributes(in data: Data) -> [String: Any]? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
    }
}
