//
//  IntroductoryOfferPushError.swift
//  Atlas
//

import Foundation

/// Why a subscription's introductory offer couldn't be created.
enum IntroductoryOfferPushError: LocalizedError, Hashable, Sendable {
    /// The subscription isn't available anywhere yet.
    case notAvailable
    /// Apple has no US price point at the offer's price.
    case noPricePoint(price: Decimal, nearest: [Decimal])
    /// No territory it runs in has a price point for it.
    case noTerritories

    var errorDescription: String? {
        let currency = CurrencyFormat.forCurrency("USD")
        switch self {
        case .notAvailable:
            return String(localized: "The subscription isn’t available in any country or region yet. Set its availability, then push again.")
        case let .noPricePoint(price, nearest):
            let options = nearest.map { currency.format($0) }.formatted(.list(type: .or))
            let suggestion = nearest.isEmpty ? "" : String(localized: " Try \(options).")
            return String(localized: "Apple has no \(currency.format(price)) price in the United States for this subscription.\(suggestion)")
        case .noTerritories:
            return String(localized: "Apple has no price for this offer in any country or region it runs in.")
        }
    }
}
