//
//  InAppPurchaseOfferCodeRoute.swift
//  Atlas
//

import Foundation

/// The offer code sheet Pricing shows for an in-app purchase App Store
/// Connect has: a new offer code, or a custom code or one-time codes for
/// one it has.
enum InAppPurchaseOfferCodeRoute: Identifiable, Hashable {
    case newOfferCode(PricingProduct)
    case customCode(PricingProduct, ExistingInAppPurchaseOfferCode)
    case oneTimeCodes(PricingProduct, ExistingInAppPurchaseOfferCode)

    var purchase: PricingProduct {
        switch self {
        case let .newOfferCode(product), let .customCode(product, _), let .oneTimeCodes(product, _): product
        }
    }

    var isCustomCode: Bool {
        if case .customCode = self { return true }
        return false
    }

    var id: String {
        switch self {
        case let .newOfferCode(product): "iapNewOfferCode.\(product.id)"
        case let .customCode(_, code): "iapCustomCode.\(code.id)"
        case let .oneTimeCodes(_, code): "iapOneTimeCodes.\(code.id)"
        }
    }
}
