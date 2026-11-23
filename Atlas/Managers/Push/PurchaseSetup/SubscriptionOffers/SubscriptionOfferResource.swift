//
//  SubscriptionOfferResource.swift
//  Atlas
//

import Foundation

/// The App Store Connect resources behind a subscription's promotional
/// offers, win-back offers and offer codes: where each is created, what
/// its prices are called, and the attribute that tells one from another on
/// a subscription (so a retry finds the one a push made before).
enum SubscriptionOfferResource: String, CaseIterable, Hashable, Sendable {
    case promotional
    case winBack
    case offerCode

    /// The JSON:API type.
    var type: String {
        switch self {
        case .promotional: "subscriptionPromotionalOffers"
        case .winBack: "winBackOffers"
        case .offerCode: "subscriptionOfferCodes"
        }
    }

    /// `POST` creates one here; `PATCH` and `DELETE` take `/{id}`.
    var path: String {
        "/v1/\(type)"
    }

    /// The type of its inline price creates.
    var priceType: String {
        switch self {
        case .promotional: "subscriptionPromotionalOfferPrices"
        case .winBack: "winBackOfferPrices"
        case .offerCode: "subscriptionOfferCodePrices"
        }
    }

    /// `offerCode`, `offerId` or `name`.
    var identityAttribute: String {
        switch self {
        case .promotional: "offerCode"
        case .winBack: "offerId"
        case .offerCode: "name"
        }
    }

    /// The subscription's relationship that lists them.
    var subscriptionRelationship: String {
        switch self {
        case .promotional: "promotionalOffers"
        case .winBack: "winBackOffers"
        case .offerCode: "offerCodes"
        }
    }

    var kind: OfferKind {
        switch self {
        case .promotional: .promotional
        case .winBack: .winBack
        case .offerCode: .offerCode
        }
    }

    /// The resource a path names, `/v1/winBackOffers` or `/v1/winBackOffers/{id}`.
    init?(path: String) {
        guard let resource = Self.allCases.first(where: { path == $0.path || path.hasPrefix($0.path + "/") }) else { return nil }
        self = resource
    }

    /// `GET` the subscription's offers of this kind with what tells them apart.
    func identitiesPath(subscriptionID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/\(subscriptionRelationship)?fields%5B\(type)%5D=\(identityAttribute)&limit=200"
    }

    /// `GET` one offer's prices with their territory and price point.
    func pricesPath(offerID: String) -> String {
        "/v1/\(type)/\(offerID)/prices?include=subscriptionPricePoint&fields%5B\(priceType)%5D=territory,subscriptionPricePoint"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=200"
    }
}
