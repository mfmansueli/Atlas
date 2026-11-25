//
//  PricingStrategyComparison.swift
//  Atlas
//

import Foundation

/// What a strategy suggestion changes, one row per setting, as the card's
/// Now and New columns show them: "Floor · 30% → 40%".
struct PricingStrategyComparison: Hashable, Sendable {
    struct Row: Hashable, Sendable, Identifiable {
        var label: String
        var now: String
        var new: String

        var id: String { label }
    }

    let rows: [Row]

    init(mode nowMode: PricingMode, strategy now: PricingStrategy, suggestion: PricingStrategySuggestion) {
        var rows: [Row] = []
        if let mode = suggestion.mode, mode != nowMode {
            rows.append(Row(label: String(localized: "Mode", comment: "kind:label"), now: nowMode.title, new: mode.title))
        }
        if let new = suggestion.strategy {
            rows += Self.rows(from: now, to: new)
        }
        self.rows = rows
    }

    /// The settings that differ, in the inspector's order.
    static func rows(from now: PricingStrategy, to new: PricingStrategy) -> [Row] {
        var rows: [Row] = []
        func add(_ label: String, _ old: String, _ next: String) {
            if old != next { rows.append(Row(label: label, now: old, new: next)) }
        }
        add(String(localized: "Method", comment: "kind:label"), now.method.title, new.method.title)
        add(String(localized: "Base country", comment: "kind:label"), territory(now.baseTerritoryID), territory(new.baseTerritoryID))
        add(String(localized: "Index", comment: "kind:label"), now.indexSource.name, new.indexSource.name)
        add(String(localized: "Intensity", comment: "kind:label"), percent(now.intensity), percent(new.intensity))
        add(String(localized: "Floor", comment: "kind:label"), percent(now.floor), percent(new.floor))
        add(String(localized: "Ceiling", comment: "kind:label"), percent(now.ceiling), percent(new.ceiling))
        add(String(localized: "Minimum proceeds", comment: "kind:label"), proceeds(now.minimumProceeds), proceeds(new.minimumProceeds))
        add(String(localized: "Discounts only", comment: "kind:label"), onOff(now.discountOnly), onOff(new.discountOnly))
        add(String(localized: "Never raise", comment: "kind:label"), onOff(now.neverRaise), onOff(new.neverRaise))
        add(String(localized: "Tiers", comment: "kind:label"), onOff(now.tiersEnabled), onOff(new.tiersEnabled))
        add(String(localized: "Rounding", comment: "kind:label"), now.rounding.title, new.rounding.title)
        for region in TerritoryRegion.allCases {
            add(region.title, percent(now.regionMultiplier(for: region)), percent(new.regionMultiplier(for: region)))
        }
        add(String(localized: "Kept at Apple’s price", comment: "kind:label"), excluded(now), excluded(new))
        return rows
    }

    private static func territory(_ id: String) -> String {
        TerritoryCatalog.standard.territory(alpha3: id)?.name ?? id
    }

    private static func percent(_ value: Decimal) -> String {
        value.doubleValue.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func proceeds(_ value: Decimal?) -> String {
        guard let value else { return String(localized: "Off", comment: "kind:label") }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func onOff(_ isOn: Bool) -> String {
        isOn ? String(localized: "On", comment: "kind:label") : String(localized: "Off", comment: "kind:label")
    }

    /// "None", "Japan", or "Japan, Korea and 2 more".
    private static func excluded(_ strategy: PricingStrategy) -> String {
        let names = strategy.excludedTerritoryIDs.sorted().map(territory)
        guard !names.isEmpty else { return String(localized: "None", comment: "kind:label") }
        guard names.count > 2 else { return names.formatted(.list(type: .and)) }
        return String(localized: "\(names[0]), \(names[1]) and \(names.count - 2) more", comment: "kind:label")
    }
}
