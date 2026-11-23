//
//  SubscriptionOffersSampleData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: the promotional offer, win-back offer and offer code Lumen
/// Monthly has in the offer scenes (`offers-all`, `promo-prices`,
/// `winback-edit`, `offer-code-custom`, `offer-code-batch`), and the
/// one-time codes Save Codes… saves.
enum SubscriptionOffersSampleData {
    static let territories = ["BRA", "DEU", "GBR", "JPN", "USA"]

    static let promotional = ExistingPromotionalOffer(
        id: "6600000001", name: "Come back for half price", identifier: "lumen_monthly_comeback",
        mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3,
        prices: ExistingOfferPrices(territoryIDs: territories, usPrice: Decimal(string: "2.99"))
    )

    static let winBack = ExistingWinBackOffer(
        id: "6600000002", referenceName: "We miss you", offerID: "lumen_monthly_winback",
        mode: .freeTrial, duration: .oneMonth,
        settings: WinBackOfferSettings(
            eligibility: WinBackEligibility(paidMonths: 2, sinceLastSubscribed: 1...6, waitMonths: 6),
            startDate: PricingSampleData.date("2026-12-01"),
            endDate: PricingSampleData.date("2027-01-31"),
            priority: .high
        ),
        prices: ExistingOfferPrices(territoryIDs: territories)
    )

    static let offerCode = ExistingOfferCode(
        id: "6600000003", name: "Podcast listeners", eligibilities: [.new, .expired],
        mode: .freeTrial, duration: .threeMonths,
        customCodes: [ExistingCustomCode(id: "6600000004", code: "LUMENPOD", numberOfCodes: 1000, expirationDate: "2026-12-31")],
        oneTimeCodes: [ExistingOneTimeCodes(id: "6600000005", numberOfCodes: 500, expirationDate: "2027-03-31", createdDate: "2026-11-02")],
        prices: ExistingOfferPrices(territoryIDs: territories)
    )

    static var extras: PurchaseExtras {
        PurchaseExtras(promotionalOffers: [promotional], winBackOffers: [winBack], offerCodes: [offerCode], offersRead: true)
    }

    /// The batch's codes, as App Store Connect's CSV.
    static var oneTimeCodesCSV: Data {
        let codes = (1...500).map { String(format: "LUMN%06d", $0 * 7919 % 1_000_000) }
        return Data((["Code"] + codes).joined(separator: "\n").utf8)
    }
}
#endif
