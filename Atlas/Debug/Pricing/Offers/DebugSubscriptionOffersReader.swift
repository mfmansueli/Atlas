//
//  DebugSubscriptionOffersReader.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: Lumen Monthly's offers and Lumen Lifetime's offer code in
/// App Store Connect for the offer scenes (other products have none), and
/// their one-time codes' CSV.
struct DebugSubscriptionOffersReader: PurchaseExtrasReading, OneTimeCodeValuesReading {
    func extras(for product: PricingProduct) async throws -> PurchaseExtras {
        switch product.id {
        case DebugPricingCatalog.lumenMonthlyID: SubscriptionOffersSampleData.extras
        case DebugPricingCatalog.lumenLifetimeID: InAppPurchaseOfferCodesSampleData.extras
        default: PurchaseExtras(offersRead: true)
        }
    }

    func oneTimeCodeValues(batchID _: String) async throws -> Data {
        SubscriptionOffersSampleData.oneTimeCodesCSV
    }
}
#endif
