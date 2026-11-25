//
//  PriceLevel.swift
//  Atlas
//

import SwiftUI

/// How a price feels for local incomes against the US base price, in five
/// steps (README-Redesign, board 73; design-tokens.json → `pricing.priceLevel`):
/// the Pricing map's tile colours, blue cheaper through grey to orange
/// pricier. Each tile also shows its code and ratio as text, so colour is
/// never the only signal.
enum PriceLevel: Int, CaseIterable, Hashable, Sendable {
    case muchCheaper
    case cheaper
    case aboutTheSame
    case pricier
    case muchPricier

    /// The feels-like ratio: the price for local incomes, in US dollars,
    /// over the US base price.
    init(ratio: Double) {
        switch ratio {
        case ..<0.7: self = .muchCheaper
        case ..<0.9: self = .cheaper
        case ..<1.15: self = .aboutTheSame
        case ..<1.6: self = .pricier
        default: self = .muchPricier
        }
    }

    /// The tile's fill.
    var fill: Color {
        switch self {
        case .muchCheaper: Color(.priceLevel0)
        case .cheaper: Color(.priceLevel1)
        case .aboutTheSame: Color(.priceLevel2)
        case .pricier: Color(.priceLevel3)
        case .muchPricier: Color(.priceLevel4)
        }
    }

    /// The code and ratio on the tile.
    var label: Color {
        switch self {
        case .muchCheaper: Color(.priceLevelLabel0)
        case .cheaper: Color(.priceLevelLabel1)
        case .aboutTheSame: Color(.priceLevelLabel2)
        case .pricier: Color(.priceLevelLabel3)
        case .muchPricier: Color(.priceLevelLabel4)
        }
    }

    /// The legend's step: "< 0.7×", "0.7–0.9×" … "≥ 1.6×".
    var legend: String {
        switch self {
        case .muchCheaper: "< 0.7×"
        case .cheaper: "0.7–0.9×"
        case .aboutTheSame: "0.9–1.15×"
        case .pricier: "1.15–1.6×"
        case .muchPricier: "≥ 1.6×"
        }
    }

    /// The histogram's bars (`pricing.priceChart`): today's prices in
    /// system grey, suggested ones in the assistant's fill.
    static let histogramNow = Color(nsColor: .systemGray)
    static let histogramSuggested = Palette.aiFill
    /// The dashed line at the US base price.
    static let histogramBaseLine = Palette.label3
}
