//
//  MCPPriceInclude.swift
//  Atlas
//

import Foundation

/// What get_prices adds to each territory beyond its price (`include`):
/// how sure and the sales behind it by default, the index, exchange rate
/// and price grid on request, so 175 countries stay a readable answer.
enum MCPPriceInclude: String, CaseIterable, Hashable, Sendable {
    /// How sure Atlas is there, with its one-line reason.
    case howSure
    /// Page views, downloads, trial and paid starts and proceeds, 90 and 28
    /// days, and the region a thin country borrows from.
    case evidence
    /// The purchasing-power value: source, edition, year, method, trust, factor.
    case index
    /// Units of the currency per US dollar.
    case exchangeRate
    /// Whether Apple's price points were read, when, and the suggested point.
    case grid

    static let defaults: Set<Self> = [.howSure, .evidence]

    /// The `include` argument's schema.
    static let property: JSONValue = [
        "type": "array",
        "items": ["type": "string", "enum": .array((allCases.map(\.rawValue) + ["all"]).map(JSONValue.string))],
        "description": """
        What each territory adds beyond its price: howSure and evidence unless given; index, exchangeRate and grid on \
        request; "all" for every one. Pair a long list with territories to keep the answer short.
        """,
    ]

    /// `include` as sent, or the defaults.
    static func parse(_ arguments: MCPToolArguments) throws -> Set<Self> {
        guard let names = try arguments.optionalStrings("include") else { return defaults }
        var result: Set<Self> = []
        for name in names {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.lowercased() == "all" { return Set(allCases) }
            guard let item = allCases.first(where: { $0.rawValue.lowercased() == key.lowercased() }) else {
                let expected = String(localized: "a list of howSure, evidence, index, exchangeRate, grid or all", comment: "kind:other")
                throw MCPToolError.invalidArgument(name: "include", expected: expected)
            }
            result.insert(item)
        }
        return result
    }
}
