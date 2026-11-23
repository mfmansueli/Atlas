//
//  InAppPurchaseOfferCodesSampleData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: the offer code Lumen Lifetime has in the in-app purchase
/// offer scenes (`iap-offers`, `iap-offer-code-custom`,
/// `iap-offer-code-batch`), with a custom code and one-time codes.
enum InAppPurchaseOfferCodesSampleData {
    static let offerCode = ExistingInAppPurchaseOfferCode(
        id: "6600000011", name: "Launch week", eligibilities: [.nonSpender, .churnedSpender],
        customCodes: [ExistingCustomCode(id: "6600000012", code: "LUMENLIFE", numberOfCodes: 2000, expirationDate: "2026-12-31")],
        oneTimeCodes: [ExistingOneTimeCodes(id: "6600000013", numberOfCodes: 300, expirationDate: "2027-03-31", createdDate: "2026-11-02")],
        prices: ExistingOfferPrices(
            territoryIDs: SubscriptionOffersSampleData.territories, usPrice: price("39.99"),
            customerPrices: ["BRA": price("199.90"), "DEU": price("39.99"), "GBR": price("34.99"), "JPN": 6000, "USA": price("39.99")]
        )
    )

    private static func price(_ text: String) -> Decimal {
        Decimal(string: text) ?? 0
    }

    static var extras: PurchaseExtras {
        PurchaseExtras(inAppPurchaseOfferCodes: [offerCode], offersRead: true)
    }
}
#endif
