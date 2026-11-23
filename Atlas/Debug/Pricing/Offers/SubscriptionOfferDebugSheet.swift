//
//  SubscriptionOfferDebugSheet.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The offer sheet a Pricing DEBUG scene opens on Lumen Monthly
/// (`PricingDebugLaunch.offerSheet`), with its sample offers
/// (`SubscriptionOffersSampleData`).
enum SubscriptionOfferDebugSheet: String, CaseIterable {
    case newPromotional = "promo-offer"
    case promotionalPrices = "promo-prices"
    case newWinBack = "winback-offer"
    case winBackSettings = "winback-edit"
    case newOfferCode = "offer-code"
    case customCode = "offer-code-custom"
    case oneTimeCodes = "offer-code-batch"

    var sceneID: String { rawValue }

    /// The route it opens for `product`.
    func route(for product: PricingProduct) -> SubscriptionOfferRoute {
        switch self {
        case .newPromotional: .newPromotional(product)
        case .promotionalPrices: .promotionalPrices(product, SubscriptionOffersSampleData.promotional)
        case .newWinBack: .newWinBack(product)
        case .winBackSettings: .winBackSettings(product, SubscriptionOffersSampleData.winBack)
        case .newOfferCode: .newOfferCode(product)
        case .customCode: .customCode(product, SubscriptionOffersSampleData.offerCode)
        case .oneTimeCodes: .oneTimeCodes(product, SubscriptionOffersSampleData.offerCode)
        }
    }
}
#endif
