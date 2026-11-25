//
//  MCPPricingStrategyJSON.swift
//  Atlas
//

import Foundation

/// How the strategy tools write a pricing strategy, and read the edits an
/// assistant sends, with the limits Customize… allows.
enum MCPPricingStrategyJSON {
    static let intensityRange: ClosedRange<Double> = 0...1
    static let floorRange: ClosedRange<Double> = 0...0.8
    static let ceilingRange: ClosedRange<Double> = 1...2
    static let regionRange: ClosedRange<Double> = 0.1...1.5

    static func json(_ strategy: PricingStrategy) -> JSONValue {
        var object: [String: JSONValue] = [
            "method": .string(strategy.method.rawValue),
            "methodTitle": .string(strategy.method.title),
            "baseTerritory": .string(strategy.baseTerritoryID),
            "indexSource": .string(strategy.indexSource.rawValue),
            "fallback": .array(strategy.fallback.map { .string(code($0)) }),
            "intensity": number(strategy.intensity),
            "floor": number(strategy.floor),
            "ceiling": number(strategy.ceiling),
            "minimumProceeds": strategy.minimumProceeds.map(number) ?? .null,
            "discountOnly": .bool(strategy.discountOnly),
            "neverRaise": .bool(strategy.neverRaise),
            "tiersEnabled": .bool(strategy.tiersEnabled),
            "rounding": .string(strategy.rounding.rawValue),
            "excludedTerritories": .array(strategy.excludedTerritoryIDs.sorted().map(JSONValue.string)),
        ]
        var regions: [String: JSONValue] = [:]
        for region in TerritoryRegion.allCases {
            regions[region.rawValue] = number(strategy.regionMultiplier(for: region))
        }
        object["regionMultipliers"] = .object(regions)
        return .object(object)
    }

    /// The `strategy` argument's schema: every setting optional.
    static let editSchema: JSONValue = MCPToolDefinition.schema([
        "method": MCPToolDefinition.string("recommended, equalized, priceIndex or regionalTiers."),
        "baseTerritory": MCPToolDefinition.string("The base country, alpha-3 (USA)."),
        "indexSource": MCPToolDefinition.string("bigMac, worldBank or imf (a custom index is imported by the person)."),
        "intensity": ["type": "number", "description": "0 (Apple's equalized price) to 1 (the full index)."],
        "floor": ["type": "number", "description": "Never below this share of the base price, 0 to 0.8."],
        "ceiling": ["type": "number", "description": "Never above this share of the base price, 1 to 2; only with discountOnly false."],
        "minimumProceeds": ["type": ["number", "null"], "description": "Minimum proceeds per country in the base currency; null turns it off."],
        "discountOnly": ["type": "boolean", "description": "Never above Apple's equalized price."],
        "neverRaise": ["type": "boolean", "description": "Never above the current price."],
        "tiersEnabled": ["type": "boolean", "description": "Snap to the price tiers."],
        "rounding": MCPToolDefinition.string("auto, ninetyNine, ninety or round."),
        "regionMultipliers": [
            "type": "object",
            "description": "For regionalTiers: americas, europe, asiaPacific, africaMiddleEast, each 0.1 to 1.5.",
        ],
        "excludedTerritories": ["type": "array", "items": ["type": "string"], "description": "Countries kept at Apple's price (alpha-3); replaces the list."],
    ])

    /// `strategy` applied over `base` as Customize… applies an edit (any
    /// change to Suggested makes it a price index); throws naming the
    /// setting that's out of range.
    static func apply(_ edits: [String: JSONValue], to base: PricingStrategy, snapshot: PriceIndexSnapshot) throws -> PricingStrategy {
        var next = base
        let edit = MCPToolArguments(edits)
        var failure: (any Error)?
        next.customize { strategy in
            do {
                try apply(edit, to: &strategy, snapshot: snapshot)
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
        return next
    }

    private static func apply(_ edit: MCPToolArguments, to strategy: inout PricingStrategy, snapshot: PriceIndexSnapshot) throws {
        try applyMethod(edit, to: &strategy, snapshot: snapshot)
        try applyLimits(edit, to: &strategy)
        try applySwitches(edit, to: &strategy)
        try applyRegions(edit, to: &strategy)
        try applyExclusions(edit, to: &strategy)
    }

    private static func applyMethod(_ edit: MCPToolArguments, to strategy: inout PricingStrategy, snapshot: PriceIndexSnapshot) throws {
        if let raw = try edit.optionalString("method") {
            guard let method = PricingMethod(rawValue: raw) else { throw invalid("strategy.method", "recommended, equalized, priceIndex or regionalTiers") }
            strategy.method = method
        }
        if let code = try edit.optionalString("baseTerritory") {
            guard let territory = TerritoryCatalog.standard.territory(code: code.uppercased()) else {
                throw invalid("strategy.baseTerritory", "an alpha-3 country code, e.g. USA")
            }
            strategy.baseTerritoryID = territory.id
        }
        if let raw = try edit.optionalString("indexSource") {
            guard let source = PriceIndexSource(rawValue: raw), source != .custom else { throw invalid("strategy.indexSource", "bigMac, worldBank or imf") }
            guard snapshot.index(source) != nil else { throw invalid("strategy.indexSource", "an index Atlas has data for") }
            strategy.indexSource = source
        }
    }

    private static func applyLimits(_ edit: MCPToolArguments, to strategy: inout PricingStrategy) throws {
        if let value = try fraction(edit, "intensity", in: intensityRange) { strategy.intensity = value }
        if let value = try fraction(edit, "floor", in: floorRange) { strategy.floor = value }
        if let value = try fraction(edit, "ceiling", in: ceilingRange) { strategy.ceiling = value }
        if edit.values["minimumProceeds"]?.isNull == true {
            strategy.minimumProceeds = nil
        } else if let value = try edit.optionalDouble("minimumProceeds") {
            guard value >= 0 else { throw invalid("strategy.minimumProceeds", "0 or more, or null") }
            strategy.minimumProceeds = rounded(value)
        }
    }

    private static func applySwitches(_ edit: MCPToolArguments, to strategy: inout PricingStrategy) throws {
        if let value = try edit.optionalBool("discountOnly") { strategy.discountOnly = value }
        if let value = try edit.optionalBool("neverRaise") { strategy.neverRaise = value }
        if let value = try edit.optionalBool("tiersEnabled") { strategy.tiersEnabled = value }
        if let raw = try edit.optionalString("rounding") {
            guard let rounding = PriceRounding(rawValue: raw) else { throw invalid("strategy.rounding", "auto, ninetyNine, ninety or round") }
            strategy.rounding = rounding
        }
    }

    private static func applyRegions(_ edit: MCPToolArguments, to strategy: inout PricingStrategy) throws {
        guard let regions = try edit.optionalObject("regionMultipliers") else { return }
        for (key, value) in regions {
            guard let region = TerritoryRegion(rawValue: key) else {
                throw invalid("strategy.regionMultipliers", "keys americas, europe, asiaPacific or africaMiddleEast")
            }
            guard let number = value.doubleValue, regionRange.contains(number) else {
                throw invalid("strategy.regionMultipliers.\(key)", "a number from 0.1 to 1.5")
            }
            strategy.regionMultipliers[region] = rounded(number)
        }
    }

    private static func applyExclusions(_ edit: MCPToolArguments, to strategy: inout PricingStrategy) throws {
        guard let codes = try edit.optionalStrings("excludedTerritories") else { return }
        var ids: Set<String> = []
        for code in codes {
            guard let territory = TerritoryCatalog.standard.territory(code: code.uppercased()) else {
                throw invalid("strategy.excludedTerritories", "alpha-3 country codes; “\(code)” isn’t one")
            }
            ids.insert(territory.id)
        }
        strategy.excludedTerritoryIDs = ids
    }

    private static func fraction(_ edit: MCPToolArguments, _ name: String, in range: ClosedRange<Double>) throws -> Decimal? {
        guard let value = try edit.optionalDouble(name) else { return nil }
        guard range.contains(value) else {
            throw invalid("strategy.\(name)", "a number from \(range.lowerBound.formatted()) to \(range.upperBound.formatted())")
        }
        return rounded(value)
    }

    /// To 0.01, as the inspector's sliders step.
    private static func rounded(_ value: Double) -> Decimal {
        Decimal(Int((value * 100).rounded())) / 100
    }

    private static func number(_ value: Decimal) -> JSONValue {
        .double(value.doubleValue)
    }

    private static func code(_ step: FallbackStep) -> String {
        switch step {
        case let .index(source): "index:\(source.rawValue)"
        case .regionMedian: "regionMedian"
        case .equalized: "equalized"
        }
    }

    private static func invalid(_ name: String, _ expected: String) -> MCPToolError {
        .invalidArgument(name: name, expected: expected)
    }
}
