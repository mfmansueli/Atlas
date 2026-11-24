//
//  NewSubscriptionPriceChoice.swift
//  Atlas
//

import Foundation

/// What a new subscription costs outside the United States, decided before
/// it's added (README — Assist §5): the recommended price everywhere,
/// Apple's prices now with the recommendations to review after the push,
/// or Apple's equalized prices, which Apple keeps updated for taxes and
/// exchange rates.
enum NewSubscriptionPriceChoice: String, CaseIterable, Hashable, Sendable, Identifiable {
    case recommended
    /// Apple's prices go live with the push; the recommendations wait on
    /// the subscription's card for Review….
    case reviewLater = "review_later"
    case equalized

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: String(localized: "Use the recommended prices", comment: "kind:option")
        case .reviewLater: String(localized: "Use Apple’s prices now, review the recommendations later", comment: "kind:option")
        case .equalized: String(localized: "Use Apple’s automatic prices", comment: "kind:option")
        }
    }

    /// What gets created, under the title.
    var detail: String {
        switch self {
        case .recommended:
            String(localized: "Prices for local purchasing power in every country and region.", comment: "kind:hint")
        case .reviewLater:
            String(localized: "Apple’s prices are live meanwhile. Review… on its card applies the ones you pick.", comment: "kind:hint")
        case .equalized:
            String(localized: "Apple keeps them updated for taxes and exchange rates.", comment: "kind:hint")
        }
    }

    /// Recommended prices for more than one country are Pro's.
    var needsPro: Bool { self == .recommended }
}
