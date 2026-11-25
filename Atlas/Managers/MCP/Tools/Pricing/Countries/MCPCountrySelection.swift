//
//  MCPCountrySelection.swift
//  Atlas
//

import Foundation

/// Which countries a price tool works on, as an assistant writes them in
/// `territories`: codes or names, and groups as Prices by Country filters
/// and selects them: "all", a region ("europe"), a currency
/// ("currency:EUR"), "suggested" (an open suggestion), "setByYou" (a price
/// someone chose) or "automatic" (Apple's automatic price). `except` takes
/// countries back out. The rows come out in catalog order, once each.
struct MCPCountrySelection: Hashable, Sendable {
    /// One item of `territories` as the assistant wrote it.
    enum Item: Hashable, Sendable {
        case all
        case region(TerritoryRegion)
        case currency(String)
        case source(Group)
        /// A code or a name.
        case territory(String)
    }

    /// The Prices by Country filters.
    enum Group: String, CaseIterable, Hashable, Sendable {
        case suggested
        case setByYou
        case automatic
    }

    var items: [Item]
    var except: [String] = []

    /// The countries the selection names, and the items that matched none.
    struct Resolution {
        var rows: [CountryPriceRow]
        var unknown: [String]
    }

    /// The schema of `territories` and `except`, shared by the price tools.
    static let properties: [String: JSONValue] = [
        "territories": [
            "type": ["array", "string"],
            "items": ["type": "string"],
            "description": .string("""
            Several countries at once: codes (BRA, BR) or names, and groups: "all", a region (americas, europe, \
            asiaPacific, africaMiddleEast), a currency ("currency:EUR"), "suggested" (an open suggestion), "setByYou" \
            (a price someone chose) or "automatic" (on Apple's automatic price). Combined, each country counts once.
            """),
        ],
        "except": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Countries to leave out of territories, e.g. [\"USA\"].",
        ],
    ]

    /// The selection in `territories` (a list, or one string) and
    /// `except`; nil when the call has no `territories`.
    static func parse(_ arguments: MCPToolArguments) throws -> MCPCountrySelection? {
        guard let value = arguments.values["territories"], !value.isNull else { return nil }
        let expected = String(localized: "a list of territory codes or groups, e.g. [\"BRA\", \"europe\", \"currency:EUR\"], or \"all\"")
        let texts: [String]
        if let text = value.stringValue {
            texts = [text]
        } else if let list = value.arrayValue {
            texts = try list.map { item in
                guard let text = item.stringValue else { throw MCPToolError.invalidArgument(name: "territories", expected: expected) }
                return text
            }
        } else {
            throw MCPToolError.invalidArgument(name: "territories", expected: expected)
        }
        let items = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.map(Self.item)
        guard !items.isEmpty else { throw MCPToolError.invalidArgument(name: "territories", expected: expected) }
        return try MCPCountrySelection(items: items, except: arguments.optionalStrings("except") ?? [])
    }

    /// One written item: a group's name (case and spaces ignored), else a
    /// territory.
    static func item(_ text: String) -> Item {
        let key = text.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "")
        if key == "all" || key == "every" { return .all }
        if key.hasPrefix("currency:") { return .currency(String(key.dropFirst("currency:".count)).uppercased()) }
        let regionKey = key.hasPrefix("region:") ? String(key.dropFirst("region:".count)) : key
        if let region = TerritoryRegion.allCases.first(where: { Self.matches(regionKey, $0) }) { return .region(region) }
        if let group = Group.allCases.first(where: { $0.rawValue.lowercased() == key }) { return .source(group) }
        return .territory(text)
    }

    /// The rows the selection names, in catalog order.
    func resolve(in rows: [CountryPriceRow]) -> Resolution {
        var chosen: Set<String> = []
        var unknown: [String] = []
        for item in items {
            let matched = rows.filter { Self.matches(item, $0) }
            if matched.isEmpty, case let .territory(text) = item { unknown.append(text) }
            chosen.formUnion(matched.map(\.id))
        }
        let left = Set(except.compactMap { code in rows.first { Self.matches(.territory(code), $0) }?.id })
        return Resolution(rows: rows.filter { chosen.contains($0.id) && !left.contains($0.id) }, unknown: unknown)
    }

    // MARK: - Private

    private static func matches(_ item: Item, _ row: CountryPriceRow) -> Bool {
        switch item {
        case .all: true
        case let .region(region): row.territory.region == region
        case let .currency(code): row.territory.currencyCode == code
        case .source(.suggested): row.hasSuggestion
        case .source(.setByYou): !row.isBase && row.source.isChosen
        case .source(.automatic): row.source == .automatic
        case let .territory(text): matchesTerritory(text, row.territory)
        }
    }

    /// Alpha-3, alpha-2 or the name, case and accents ignored.
    private static func matchesTerritory(_ text: String, _ territory: Territory) -> Bool {
        let code = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code == territory.id || code == territory.alpha2 { return true }
        return territory.name.compare(text.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// "europe", "asiapacific", "africa&middleeast" or the region's code name.
    private static func matches(_ key: String, _ region: TerritoryRegion) -> Bool {
        key == region.rawValue.lowercased() || key == region.title.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
