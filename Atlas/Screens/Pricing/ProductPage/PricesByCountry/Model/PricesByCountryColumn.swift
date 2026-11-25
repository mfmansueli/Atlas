//
//  PricesByCountryColumn.swift
//  Atlas
//

import Foundation

/// Prices by Country's columns (board 73). Country or region, Price and
/// Change always show; In US$, Proceeds and How it's set show by default;
/// the Columns menu adds Feels Like, Equalized, Currency, Source and Reason.
enum PricesByCountryColumn: String, CaseIterable, Identifiable, Hashable, Sendable {
    case country
    case price
    case dollars
    case proceeds
    case source
    case feelsLike
    case equalized
    case currency
    case provenance
    case reason
    case change

    var id: String { rawValue }

    /// The `TableColumnCustomization` id.
    var customizationID: String { "countries.\(rawValue)" }

    var title: String {
        switch self {
        case .country: String(localized: "Country or region", comment: "kind:column")
        case .price: String(localized: "Price", comment: "kind:column")
        case .dollars: String(localized: "In US$", comment: "kind:column")
        case .proceeds: String(localized: "Proceeds", comment: "kind:column")
        case .source: String(localized: "How it’s set", comment: "kind:column")
        case .feelsLike: String(localized: "Feels Like", comment: "kind:field-label")
        case .equalized: String(localized: "Equalized", comment: "kind:column")
        case .currency: String(localized: "Currency", comment: "kind:column")
        case .provenance: String(localized: "Source", comment: "kind:column")
        case .reason: String(localized: "Reason", comment: "kind:column")
        case .change: String(localized: "Change", comment: "kind:column")
        }
    }

    /// Country, Price and Change can't be hidden.
    var isAlwaysShown: Bool {
        [.country, .price, .change].contains(self)
    }

    /// Shown until the person hides it.
    var isShownByDefault: Bool {
        isAlwaysShown || [.dollars, .proceeds, .source].contains(self)
    }

    /// The Columns menu's choices, in table order.
    static let optional = allCases.filter { !$0.isAlwaysShown }

    /// Narrower than 780 pt these fold under the country's name, and the
    /// Columns menu's own ones hide.
    var foldsWhenNarrow: Bool {
        !isAlwaysShown
    }
}
