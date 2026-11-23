//
//  InAppPurchaseOfferCodeResource.swift
//  Atlas
//

import Foundation

/// App Store Connect's resources behind an in-app purchase's offer codes
/// (API 4.6.1): the offer codes (`/v1/inAppPurchaseOfferCodes`, listed
/// under `/v2/inAppPurchases/{id}/offerCodes`), their inline prices
/// (`inAppPurchaseOfferPrices`, each a territory and an
/// `inAppPurchasePricePoints` point), custom codes
/// (`/v1/inAppPurchaseOfferCodeCustomCodes`) and batches of one-time codes
/// (`/v1/inAppPurchaseOfferCodeOneTimeUseCodes`, their values a CSV file).
/// An offer code, custom code or batch only ever changes `active`.
enum InAppPurchaseOfferCodeResource {
    static let offerCodeType = "inAppPurchaseOfferCodes"
    static let offerCodesPath = "/v1/\(offerCodeType)"
    static let priceType = "inAppPurchaseOfferPrices"
    static let customCodeType = "inAppPurchaseOfferCodeCustomCodes"
    static let customCodesPath = "/v1/\(customCodeType)"
    static let oneTimeCodesType = "inAppPurchaseOfferCodeOneTimeUseCodes"
    static let oneTimeCodesPath = "/v1/\(oneTimeCodesType)"

    /// `GET` the purchase's offer codes with every attribute.
    static func listPath(purchaseID: String) -> String {
        "/v2/inAppPurchases/\(purchaseID)/offerCodes?fields%5BinAppPurchaseOfferCodes%5D=name,customerEligibilities,"
            + "productionCodeCount,sandboxCodeCount,active&limit=200"
    }

    /// `GET` the purchase's offer codes' names, which tell them apart (so a
    /// retry finds the one a push made before).
    static func identitiesPath(purchaseID: String) -> String {
        "/v2/inAppPurchases/\(purchaseID)/offerCodes?fields%5BinAppPurchaseOfferCodes%5D=name&limit=200"
    }

    /// `GET` one offer code's prices with their territory and price point.
    static func pricesPath(offerCodeID: String) -> String {
        "/v1/inAppPurchaseOfferCodes/\(offerCodeID)/prices?include=pricePoint&fields%5BinAppPurchaseOfferPrices%5D=territory,pricePoint"
            + "&fields%5BinAppPurchasePricePoints%5D=customerPrice&limit=200"
    }

    /// `GET` one offer code's custom codes.
    static func customCodesListPath(offerCodeID: String) -> String {
        "/v1/inAppPurchaseOfferCodes/\(offerCodeID)/customCodes"
            + "?fields%5BinAppPurchaseOfferCodeCustomCodes%5D=customCode,numberOfCodes,createdDate,expirationDate,active&limit=200"
    }

    /// `GET` one offer code's batches of one-time codes.
    static func oneTimeCodesListPath(offerCodeID: String) -> String {
        "/v1/inAppPurchaseOfferCodes/\(offerCodeID)/oneTimeUseCodes"
            + "?fields%5BinAppPurchaseOfferCodeOneTimeUseCodes%5D=numberOfCodes,createdDate,expirationDate,active,environment&limit=200"
    }

    /// `GET` a batch's codes as a CSV file.
    static func valuesPath(batchID: String) -> String {
        "/v1/inAppPurchaseOfferCodeOneTimeUseCodes/\(batchID)/values"
    }

    /// `{"data": {"type": "inAppPurchaseOfferCodes", "id": …}}`: a custom
    /// code's or batch's offer code.
    static func offerCodeRelationship(_ offerCodeID: String) -> [String: Any] {
        ["offerCode": ["data": ["type": offerCodeType, "id": offerCodeID]]]
    }
}
