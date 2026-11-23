//
//  DebugSubscriptionOffersReader.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: Lumen Monthly's offers in App Store Connect for the offer
/// scenes (other products have none), and its one-time codes' CSV.
struct DebugSubscriptionOffersReader: PurchaseExtrasReading, OneTimeCodeValuesReading {
    func extras(for product: PricingProduct) async throws -> PurchaseExtras {
        product.id == DebugPricingCatalog.lumenMonthlyID ? SubscriptionOffersSampleData.extras : PurchaseExtras(offersRead: true)
    }

    func oneTimeCodeValues(batchID _: String) async throws -> Data {
        SubscriptionOffersSampleData.oneTimeCodesCSV
    }
}
#endif
