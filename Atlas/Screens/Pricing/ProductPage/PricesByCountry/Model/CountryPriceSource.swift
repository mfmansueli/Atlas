//
//  CountryPriceSource.swift
//  Atlas
//

import Foundation

/// How a country's price is set, as Prices by Country's "How it's set"
/// column says it (board 73).
enum CountryPriceSource: String, CaseIterable, Hashable, Sendable {
    /// The base territory's own price: the others are equalized from it.
    case basePrice
    /// Apple's automatic price. An in-app purchase's follows exchange
    /// rates and tax; a subscription's is the base price equalized, since
    /// App Store Connect has no automatic subscription prices.
    case automatic
    /// A price someone chose for this country.
    case setByYou
    /// A suggestion accepted here or on the product card, not pushed yet.
    case acceptedSuggestion
    /// A suggestion stepped to a nearby price point before it was accepted.
    case adjustedSuggestion

    var title: String {
        switch self {
        case .basePrice: String(localized: "Base price", comment: "kind:label")
        case .automatic: String(localized: "Automatic", comment: "kind:label")
        case .setByYou: String(localized: "Set by you", comment: "kind:label")
        case .acceptedSuggestion: String(localized: "Accepted suggestion", comment: "kind:label")
        case .adjustedSuggestion: String(localized: "Adjusted suggestion", comment: "kind:field-label")
        }
    }

    /// A price someone picked (the base one too), which Set by You lists
    /// and Set N to Automatic can take back.
    var isChosen: Bool { self != .automatic }
}
