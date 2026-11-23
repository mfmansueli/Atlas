//
//  PricingSheetError.swift
//  Atlas
//

import Foundation

/// Why a product's prices can't be shown, when it's a state Pricing offers
/// a way out of rather than a failure.
enum PricingSheetError: LocalizedError, Hashable, Sendable {
    /// A subscription made without prices (in App Store Connect, or one
    /// whose starting price couldn't be set): Pricing offers Set Starting
    /// Price.
    case noStartingPrice(productName: String)
    /// An in-app purchase without a price: Atlas shows in-app purchase
    /// prices and doesn't set them, so it's set in App Store Connect.
    case noInAppPurchasePrice(productName: String)

    var errorDescription: String? {
        switch self {
        case let .noStartingPrice(name): String(localized: "\(name) has no price in the United States yet.")
        case let .noInAppPurchasePrice(name): String(localized: "\(name) has no price yet. Set it in App Store Connect.")
        }
    }

    /// Pricing offers Set Starting Price (subscriptions only).
    var offersStartingPrice: Bool {
        if case .noStartingPrice = self { true } else { false }
    }

    /// What the product's card says instead of its prices.
    var cardText: String {
        switch self {
        case .noStartingPrice: String(localized: "No price yet. Set its starting price first.")
        case .noInAppPurchasePrice: String(localized: "No price yet. Set it in App Store Connect.")
        }
    }
}
