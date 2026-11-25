//
//  PricingPreviewInRow.swift
//  Atlas
//

import Foundation

/// A line of "Preview in"'s App Store list: a product's price in the chosen
/// country, or a grey skeleton while that product's prices still load.
enum PricingPreviewInRow: Identifiable, Equatable, Sendable {
    case price(PricingPreviewInPrice)
    case loading(PricingProduct.ID)

    var id: PricingProduct.ID {
        switch self {
        case let .price(price): price.id
        case let .loading(id): id
        }
    }
}
