//
//  InAppPurchaseOfferCodeDebugSheet.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The offer code sheet a Pricing DEBUG scene opens on Lumen Lifetime
/// (`PricingDebugLaunch.inAppPurchaseOfferSheet`), with its sample offer
/// code (`InAppPurchaseOfferCodesSampleData`).
enum InAppPurchaseOfferCodeDebugSheet: String, CaseIterable {
    case newOfferCode = "iap-offer-code"
    case customCode = "iap-offer-code-custom"
    case oneTimeCodes = "iap-offer-code-batch"

    var sceneID: String { rawValue }

    /// The route it opens for `purchase`.
    func route(for purchase: PricingProduct) -> InAppPurchaseOfferCodeRoute {
        switch self {
        case .newOfferCode: .newOfferCode(purchase)
        case .customCode: .customCode(purchase, InAppPurchaseOfferCodesSampleData.offerCode)
        case .oneTimeCodes: .oneTimeCodes(purchase, InAppPurchaseOfferCodesSampleData.offerCode)
        }
    }
}
#endif
