//
//  SubscriptionOfferRoute.swift
//  Atlas
//

import Foundation

/// The offer sheet Pricing shows for a subscription App Store Connect has:
/// a new promotional offer, win-back offer or offer code, a promotional
/// offer's prices, a win-back offer's settings, or codes for an offer code.
enum SubscriptionOfferRoute: Identifiable, Hashable {
    case newPromotional(PricingProduct)
    case promotionalPrices(PricingProduct, ExistingPromotionalOffer)
    case newWinBack(PricingProduct)
    case winBackSettings(PricingProduct, ExistingWinBackOffer)
    case newOfferCode(PricingProduct)
    case customCode(PricingProduct, ExistingOfferCode)
    case oneTimeCodes(PricingProduct, ExistingOfferCode)

    var subscription: PricingProduct {
        switch self {
        case let .newPromotional(product), let .promotionalPrices(product, _), let .newWinBack(product),
             let .winBackSettings(product, _), let .newOfferCode(product), let .customCode(product, _),
             let .oneTimeCodes(product, _):
            product
        }
    }

    var isCustomCode: Bool {
        if case .customCode = self { return true }
        return false
    }

    var id: String {
        switch self {
        case let .newPromotional(product): "newPromotional.\(product.id)"
        case let .promotionalPrices(_, offer): "promotionalPrices.\(offer.id)"
        case let .newWinBack(product): "newWinBack.\(product.id)"
        case let .winBackSettings(_, offer): "winBackSettings.\(offer.id)"
        case let .newOfferCode(product): "newOfferCode.\(product.id)"
        case let .customCode(_, code): "customCode.\(code.id)"
        case let .oneTimeCodes(_, code): "oneTimeCodes.\(code.id)"
        }
    }
}
