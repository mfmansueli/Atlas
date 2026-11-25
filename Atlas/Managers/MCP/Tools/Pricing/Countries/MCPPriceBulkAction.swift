//
//  MCPPriceBulkAction.swift
//  Atlas
//

import Foundation

/// What `propose_prices` does to every country `territories` names, as
/// Prices by Country's selection does it: one price (when they share a
/// currency), Apple's automatic price (Set N to Automatic), each country's
/// open suggestion (Accept N Suggested), or taking back the assistant's
/// own proposals there.
enum MCPPriceBulkAction: Hashable, Sendable {
    case price(Decimal)
    case automatic
    case acceptSuggestions
    case withdraw

    /// The schema of the actions' arguments beside `territories`.
    static let properties: [String: JSONValue] = [
        "acceptSuggestions": [
            "type": "boolean",
            "description": "true proposes each selected country's open suggestion (get_prices' suggested), as Accept N Suggested does.",
        ],
        "withdraw": [
            "type": "boolean",
            "description": "true takes back your own proposals waiting for these countries (the person's stay).",
        ],
    ]

    /// The one action the call asks for; throws for none or several.
    static func parse(_ arguments: MCPToolArguments) throws -> MCPPriceBulkAction {
        var actions: [MCPPriceBulkAction] = []
        if let value = arguments.values["price"], !value.isNull {
            guard let price = MCPPriceValue.decimal(from: value) else {
                throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "a positive price in the countries’ currency, e.g. 4.99"))
            }
            actions.append(.price(price))
        }
        if try arguments.optionalBool("automatic") == true { actions.append(.automatic) }
        if try arguments.optionalBool("acceptSuggestions") == true { actions.append(.acceptSuggestions) }
        if try arguments.optionalBool("withdraw") == true { actions.append(.withdraw) }
        guard actions.count == 1, let action = actions.first else {
            throw MCPToolError.invalidArgument(
                name: "territories",
                expected: String(localized: "territories with one of price, automatic: true, acceptSuggestions: true or withdraw: true")
            )
        }
        return action
    }

    /// Why one price can't go to countries in several currencies, or nil.
    static func currencyRefusal(_ rows: [CountryPriceRow]) -> String? {
        let currencies = Array(Set(rows.map(\.territory.currencyCode))).sorted()
        guard currencies.count > 1 else { return nil }
        let list = currencies.formatted(.list(type: .and))
        return String(localized: """
        One price fits one currency, and these countries use \(list). Narrow territories to one currency \
        ("currency:EUR"), or send prices: [{territory, price}] with each country's own price.
        """)
    }

    /// No open suggestion in a country Accept Suggested selected.
    static func noSuggestionNote(_ row: CountryPriceRow) -> String {
        String(localized: "\(row.territory.name) has no open suggestion, so nothing was queued there.")
    }

    /// Automatic selected a country already on Apple's automatic price.
    static func alreadyAutomaticNote(_ row: CountryPriceRow) -> String {
        String(localized: "\(row.territory.name) is already on Apple’s automatic price; nothing was queued.")
    }
}
