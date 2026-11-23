//
//  MCPPriceCatalog+OfferPrices.swift
//  Atlas
//

import Foundation

extension MCPPriceCatalog {
    /// Why an offer of `mode` is refused before it's checked: a paid one
    /// (pay as you go or pay up front) sets a price, which an app set to
    /// Keep my prices never gets proposed; a free trial sets none. The same
    /// rule for introductory, promotional and win-back offers and offer codes.
    func offerPriceRefusal(for mode: OfferPaymentMode) -> String? {
        self.mode == .keepPrices && mode != .freeTrial ? keepPricesRefusal : nil
    }
}
