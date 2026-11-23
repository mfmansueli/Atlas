//
//  OfferPriceOwner.swift
//  Atlas
//

import Foundation

/// Whose price points an offer is priced from: a subscription's (its
/// promotional offers, win-back offers and offer codes) or an in-app
/// purchase's (its offer codes). Each has its own availability, price
/// points and equalizations in App Store Connect, and its offers' inline
/// prices name their point by a relationship of their own.
enum OfferPriceOwner: Hashable, Sendable {
    case subscription(String)
    case inAppPurchase(String)

    /// The subscription's or in-app purchase's App Store Connect ID.
    var id: String {
        switch self {
        case let .subscription(id), let .inAppPurchase(id): id
        }
    }

    /// The key `OfferPricesPlan` keeps the ID under.
    var planKey: String {
        switch self {
        case .subscription: "subscriptionID"
        case .inAppPurchase: "inAppPurchaseID"
        }
    }

    /// `GET` where it's sold.
    var availabilityPath: String {
        switch self {
        case let .subscription(id):
            "/v1/subscriptions/\(id)/subscriptionAvailability?fields%5BsubscriptionAvailabilities%5D=availableInNewTerritories"
        case let .inAppPurchase(id):
            "/v2/inAppPurchases/\(id)/inAppPurchaseAvailability?fields%5BinAppPurchaseAvailabilities%5D=availableInNewTerritories"
        }
    }

    /// `GET` an availability's territories.
    func availableTerritoriesPath(availabilityID: String) -> String {
        switch self {
        case .subscription:
            IntroductoryOfferEverywhere.availableTerritoriesPath(availabilityID: availabilityID)
        case .inAppPurchase:
            "/v1/inAppPurchaseAvailabilities/\(availabilityID)/availableTerritories?fields%5Bterritories%5D=currency&limit=200"
        }
    }

    /// `GET` its price points in a territory.
    func pricePointsPath(territoryID: String) -> String {
        switch self {
        case let .subscription(id):
            "/v1/subscriptions/\(id)/pricePoints?filter%5Bterritory%5D=\(territoryID)&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"
        case let .inAppPurchase(id):
            "/v2/inAppPurchases/\(id)/pricePoints?filter%5Bterritory%5D=\(territoryID)&fields%5BinAppPurchasePricePoints%5D=customerPrice&limit=8000"
        }
    }

    /// `GET` the points Apple equalizes with one, with their territory.
    func equalizationsPath(pricePointID: String) -> String {
        switch self {
        case .subscription:
            IntroductoryOfferEverywhere.equalizationsPath(pricePointID: pricePointID)
        case .inAppPurchase:
            "/v1/inAppPurchasePricePoints/\(pricePointID)/equalizations?include=territory"
                + "&fields%5BinAppPurchasePricePoints%5D=customerPrice,territory&fields%5Bterritories%5D=currency&limit=200"
        }
    }

    /// An inline price's relationship to its point.
    var pricePointRelationship: String {
        switch self {
        case .subscription: "subscriptionPricePoint"
        case .inAppPurchase: "pricePoint"
        }
    }

    /// The JSON:API type of its price points.
    var pricePointType: String {
        switch self {
        case .subscription: "subscriptionPricePoints"
        case .inAppPurchase: "inAppPurchasePricePoints"
        }
    }

    /// An offer create's or update's `relationships.prices.data` and
    /// `included`: one inline price of `type` per territory, `${price1}`…,
    /// with its territory and (for a paid subscription offer) its point.
    func inlinePrices(_ prices: [OfferPriceReader.Price], type: String) -> (data: [[String: Any]], included: [[String: Any]]) {
        let localIDs = prices.indices.map { "${price\($0 + 1)}" }
        let included = zip(localIDs, prices).map { localID, price in
            var related: [String: Any] = ["territory": ["data": ["type": "territories", "id": price.territoryID]]]
            if let point = price.pricePointID {
                related[pricePointRelationship] = ["data": ["type": pricePointType, "id": point]]
            }
            return ["type": type, "id": localID, "relationships": related] as [String: Any]
        }
        return (localIDs.map { ["type": type, "id": $0] }, included)
    }

    /// Why its offer can't be priced: it isn't sold anywhere yet.
    var notAvailable: SubscriptionOfferPushError {
        switch self {
        case .subscription: .notAvailable
        case .inAppPurchase: .inAppPurchaseNotAvailable
        }
    }

    /// Why its offer can't be priced: Apple has no point at `price` there.
    func noPricePoint(territoryID: String, price: Decimal, nearest: [Decimal]) -> SubscriptionOfferPushError {
        switch self {
        case .subscription: .noPricePoint(territoryID: territoryID, price: price, nearest: nearest)
        case .inAppPurchase: .noInAppPurchasePricePoint(territoryID: territoryID, price: price, nearest: nearest)
        }
    }
}
