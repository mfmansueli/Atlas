//
//  PriceMatrixModel+Views.swift
//  Atlas
//

import Foundation

/// The matrix's prices as other views show them: the schedule's increases
/// and each offer's derived prices.
/// Each reads the price a territory shows: the queued one, else today's.
extension PriceMatrixModel {
    /// Territories whose queued price goes up, with their existing
    /// subscribers when `subscribers` knows them.
    func increaseConsent(subscribers: [String: Int]?) -> PriceIncreaseConsent {
        PriceIncreaseConsent(rows: rows, subscribers: subscribers)
    }

    /// The offer's price in every territory, from the price it shows,
    /// snapped to its price points; most-viewed territories first.
    func offerPrices(for offer: SubscriptionOffer) -> [OfferPrice] {
        rows.sorted(by: PricingRow.defaultOrder).map { row in
            OfferPricing.price(
                offer,
                subscriptionPrice: row.shownPrice,
                territory: row.territory,
                ladder: ladder(for: row),
                commission: calculator.commission
            )
        }
    }
}
