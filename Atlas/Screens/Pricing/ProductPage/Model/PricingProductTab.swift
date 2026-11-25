//
//  PricingProductTab.swift
//  Atlas
//

import Foundation

/// The tabs of a product's page in Pricing (board 73): Prices by Country ·
/// Results · Offers · Review Screenshot · Details.
enum PricingProductTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case pricesByCountry
    case results
    case offers
    case reviewScreenshot
    case details

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pricesByCountry: String(localized: "Prices by Country", comment: "kind:segment")
        case .results: String(localized: "Results", comment: "kind:segment")
        case .offers: String(localized: "Offers", comment: "kind:segment")
        case .reviewScreenshot: String(localized: "Review Screenshot", comment: "kind:segment")
        case .details: String(localized: "Details", comment: "kind:segment")
        }
    }
}
