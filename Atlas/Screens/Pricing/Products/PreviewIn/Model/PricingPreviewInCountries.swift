//
//  PricingPreviewInCountries.swift
//  Atlas
//

import Foundation

/// Every country and region "Preview in" can show, by name: the menu's
/// groups (with price changes first, then all of them), Find a country or
/// currency, and ‹ › to the previous or next country with a change.
struct PricingPreviewInCountries: Equatable, Sendable {
    /// By name.
    let countries: [PricingPreviewInCountry]

    init(territories: [Territory], changedIDs: Set<String>) {
        var seen = Set<String>()
        countries = territories
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { PricingPreviewInCountry(territory: $0, hasChange: changedIDs.contains($0.id)) }
    }

    var count: Int { countries.count }

    var isEmpty: Bool { countries.isEmpty }

    /// The countries with a price change, by name.
    var changed: [PricingPreviewInCountry] { countries.filter(\.hasChange) }

    func country(id: String) -> PricingPreviewInCountry? {
        countries.first { $0.id == id }
    }

    /// Every country that matches, once each, by name.
    func matching(_ query: String) -> [PricingPreviewInCountry] {
        countries.filter { $0.matches(query) }
    }

    /// With price changes, then All countries and regions (which lists the
    /// changed ones again); a group with no match is left out.
    func groups(matching query: String) -> [PricingPreviewInGroup] {
        let found = matching(query)
        return [
            PricingPreviewInGroup(kind: .withChanges, countries: found.filter(\.hasChange)),
            PricingPreviewInGroup(kind: .all, countries: found),
        ]
        .filter { !$0.countries.isEmpty }
    }

    /// "175", or "3 of 175" while finding.
    func countText(matching query: String) -> String {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return "\(count)" }
        return String(localized: "\(matching(query).count) of \(count)", comment: "kind:label")
    }

    /// ›: the next country with a change after this one, by name, wrapping
    /// around; from a country without a change, the first one after it.
    /// Nil when no country has a change.
    func next(after id: String) -> PricingPreviewInCountry? {
        step(from: id, forward: true)
    }

    /// ‹: the same, backwards.
    func previous(before id: String) -> PricingPreviewInCountry? {
        step(from: id, forward: false)
    }

    private func step(from id: String, forward: Bool) -> PricingPreviewInCountry? {
        let changed = changed
        guard !changed.isEmpty else { return nil }
        if let index = changed.firstIndex(where: { $0.id == id }) {
            let offset = forward ? 1 : changed.count - 1
            return changed[(index + offset) % changed.count]
        }
        // Not a changed country: the nearest one on that side by name.
        guard let position = countries.firstIndex(where: { $0.id == id }) else {
            return forward ? changed.first : changed.last
        }
        let after = countries[countries.index(after: position)...].filter(\.hasChange)
        let before = countries[..<position].filter(\.hasChange)
        return forward ? after.first ?? before.first : before.last ?? after.last
    }
}
