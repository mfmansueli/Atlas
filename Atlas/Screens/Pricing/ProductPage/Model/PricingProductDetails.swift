//
//  PricingProductDetails.swift
//  Atlas
//

import Foundation

/// The Details tab's rows (board 73): type, product ID, subscription group,
/// base price, where it's available, Family Sharing, Apple's commission
/// (the rate Proceeds use, from Settings), the exchange rates In US$ and
/// Proceeds use (board 76: here and in the footer, never in the banner)
/// and the tax category. A row whose
/// fact is still being read has no value yet (a skeleton); one that
/// couldn't be read, or that doesn't apply (an in-app purchase's group), is
/// left out. App Store Connect's API has no tax category for subscriptions
/// or in-app purchases, so that row says where it's set rather than guess.
struct PricingProductDetails: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        var kind: PricingProductDetailKind
        var title: String
        /// Nil while it's being read.
        var value: String?

        var id: String { kind.rawValue }
    }

    var rows: [Row]

    /// `basePrice` is "$39.99 in the United States", as the product's card
    /// says it; nil while its prices are read (or when they couldn't be:
    /// `isReadingPrices` false).
    static func make(
        product: PricingProduct,
        group: PricingProductGroup?,
        basePrice: String?,
        isReadingPrices: Bool,
        facts: LoadState<PricingProductFacts>,
        territoryTotal: Int,
        commission: Commission = .standard,
        exchangeRates: ExchangeRates? = nil
    ) -> Self {
        var rows = [
            Row(kind: .type, title: String(localized: "Type", comment: "kind:label"), value: typeText(product)),
            Row(kind: .productID, title: String(localized: "Product ID", comment: "kind:label"), value: product.productID),
        ]
        if !product.isInAppPurchase, let group, !group.isInAppPurchases {
            rows.append(Row(kind: .group, title: String(localized: "Subscription group", comment: "kind:label"), value: group.name))
        }
        if let basePrice {
            rows.append(Row(kind: .basePrice, title: basePriceTitle, value: basePrice))
        } else if isReadingPrices {
            rows.append(Row(kind: .basePrice, title: basePriceTitle, value: nil))
        }
        switch facts {
        case .idle, .loading:
            rows.append(Row(kind: .availability, title: availabilityTitle, value: nil))
            rows.append(Row(kind: .familySharing, title: familySharingTitle, value: nil))
        case let .loaded(facts):
            if let count = facts.availableTerritoryCount {
                rows.append(Row(kind: .availability, title: availabilityTitle, value: availabilityText(count, of: territoryTotal)))
            }
            if let isOn = facts.isFamilySharable {
                let value = isOn ? String(localized: "On", comment: "kind:label") : String(localized: "Off", comment: "kind:label")
                rows.append(Row(kind: .familySharing, title: familySharingTitle, value: value))
            }
        case .failed:
            break
        }
        rows.append(Row(kind: .commission, title: String(localized: "Apple’s commission", comment: "kind:label"), value: commission.title))
        if let exchangeRates {
            rows.append(Row(kind: .exchangeRates, title: String(localized: "Exchange rates", comment: "kind:label"), value: exchangeRates.sourceLine))
        }
        rows.append(Row(
            kind: .taxCategory,
            title: String(localized: "Tax category", comment: "kind:field-label"),
            value: String(localized: "The app’s, set in App Store Connect", comment: "kind:hint")
        ))
        return PricingProductDetails(rows: rows)
    }

    /// "Subscription · 1 year", "Non-consumable", as the product's card says it.
    static func typeText(_ product: PricingProduct) -> String {
        guard !product.isInAppPurchase else { return product.durationText }
        return String(localized: "Subscription · \(product.durationText)")
    }

    /// "175 of 175 countries and regions", "Not available anywhere yet".
    static func availabilityText(_ count: Int, of total: Int) -> String {
        guard count > 0 else { return String(localized: "Not available in any country or region yet", comment: "kind:label") }
        return String(localized: "\(count) of \(max(count, total)) countries and regions", comment: "kind:label")
    }

    private static var basePriceTitle: String { String(localized: "Base price", comment: "kind:label") }
    private static var availabilityTitle: String { String(localized: "Available in", comment: "kind:label") }
    private static var familySharingTitle: String { String(localized: "Family Sharing", comment: "kind:label") }
}
