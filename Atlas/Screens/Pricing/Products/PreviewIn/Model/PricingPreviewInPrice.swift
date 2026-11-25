//
//  PricingPreviewInPrice.swift
//  Atlas
//

import Foundation

/// One product in "Preview in", as the App Store would show it in the chosen
/// country: the price people pay there (the new one while it's changing),
/// the old price struck through with Suggested or Not pushed, and about how
/// much that is in US dollars.
struct PricingPreviewInPrice: Identifiable, Equatable, Sendable {
    var id: PricingProduct.ID
    var name: String
    /// "R$ 129,90": the new price while it's changing, else today's.
    var price: String
    /// Today's price, struck through, while it's changing.
    var oldPrice: String?
    var tag: PricingPreviewInTag?
    /// "$26", "$4.99": the price shown, from bundled exchange rates; nil
    /// where Atlas has no rate.
    var dollars: String?
    /// "per year", "once"; nil when Atlas doesn't know the period.
    var period: String?

    var isChanging: Bool { tag != nil }

    /// "≈ $26 per year".
    var dollarsText: String? {
        guard let dollars else { return nil }
        return ["≈ \(dollars)", period].compactMap(\.self).joined(separator: " ")
    }

    /// "Lumen Plus Annual, R$ 129,90 per year, about $26. Suggested, was R$ 249,90."
    var accessibilityText: String {
        var text = [name, [price, period].compactMap(\.self).joined(separator: " ")].joined(separator: ", ")
        if let dollars {
            text += String(localized: ", about \(dollars).", comment: "kind:accessibility-label")
        } else {
            text += "."
        }
        if let tag, let oldPrice {
            text += " " + String(localized: "\(tag.title), was \(oldPrice).", comment: "kind:accessibility-label")
        }
        return text
    }

    /// Reads a product's price in one country from its card.
    static func make(product: PricingProduct, price: PricingProductCard.TerritoryPrice) -> PricingPreviewInPrice {
        let tag: PricingPreviewInTag? = price.next == nil ? nil : price.isQueued ? .notPushed : .suggested
        return PricingPreviewInPrice(
            id: product.id,
            name: product.name,
            price: price.next ?? price.now,
            oldPrice: price.next == nil ? nil : price.now,
            tag: tag,
            dollars: price.dollars.map(dollarsText),
            period: periodText(for: product)
        )
    }

    /// Whole dollars from $10 ("$46"), cents below ("$4.99").
    static func dollarsText(_ amount: Decimal) -> String {
        amount < 10 ? CurrencyFormat.usd.format(amount) : CurrencyFormat.usd.formatWhole(amount)
    }

    /// How often people pay it: "per month", "every 3 months", "once".
    static func periodText(for product: PricingProduct) -> String? {
        if product.isInAppPurchase { return String(localized: "once", comment: "kind:label") }
        guard let period = product.period else { return nil }
        return switch period {
        case .oneWeek: String(localized: "per week", comment: "kind:label")
        case .oneMonth: String(localized: "per month", comment: "kind:label")
        case .twoMonths: String(localized: "every 2 months", comment: "kind:label")
        case .threeMonths: String(localized: "every 3 months", comment: "kind:label")
        case .sixMonths: String(localized: "every 6 months", comment: "kind:label")
        case .oneYear: String(localized: "per year", comment: "kind:label")
        }
    }
}
