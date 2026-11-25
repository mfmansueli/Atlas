//
//  PricesByCountryFiltersPopover.swift
//  Atlas
//

import SwiftUI

/// The Filters popover: a region's countries, and only those that change,
/// go up, or have a fallback factor.
struct PricesByCountryFiltersPopover: View {
    @Binding var filters: PricesByCountryFilters

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Region", comment: "kind:section-title")
                .atlasTextStyle(.headline)
            ForEach(TerritoryRegion.allCases, id: \.self) { region in
                Toggle(region.title, isOn: Binding(
                    get: { filters.regions.contains(region) },
                    set: { isOn in
                        if isOn { filters.regions.insert(region) } else { filters.regions.remove(region) }
                    }
                ))
                .accessibilityIdentifier("countries.filters.region.\(region.rawValue)")
            }
            Divider()
            Toggle(String(localized: "Changed Only", comment: "kind:menu-item"), isOn: $filters.changedOnly)
                .accessibilityIdentifier("countries.filters.changed")
            Toggle(String(localized: "Increases Only", comment: "kind:menu-item"), isOn: $filters.increasesOnly)
                .accessibilityIdentifier("countries.filters.increases")
            Toggle(String(localized: "Fallback Only", comment: "kind:menu-item"), isOn: $filters.fallbackOnly)
                .accessibilityIdentifier("countries.filters.fallback")
            if filters.isActive {
                Divider()
                Button(String(localized: "Clear Filters", comment: "kind:button")) { filters = PricesByCountryFilters() }
                    .plainButton()
                    .accessibilityIdentifier("countries.filters.clear")
            }
        }
        .toggleStyle(.checkbox)
        .atlasTextStyle(.body)
        .padding(Spacing.large)
        .frame(width: Metrics.countriesFiltersWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.filters.popover")
    }
}
