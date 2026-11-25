//
//  PricesByCountryFiltersButton.swift
//  Atlas
//

import SwiftUI

/// Filters, with how many are on (board 73, `pr-prod-filters`): regions,
/// then Changed Only, Increases Only and Fallback Only. An icon at 860 × 560.
struct PricesByCountryFiltersButton: View {
    @Bindable var state: PricesByCountryState
    var isCompact = false

    var body: some View {
        Button {
            state.isFiltersPresented.toggle()
        } label: {
            HStack(spacing: Spacing.xxSmall) {
                Image(systemName: state.filters.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(state.filters.isActive ? Palette.accent : Palette.label2)
                if !isCompact {
                    Text(state.filters.isActive
                        ? String(localized: "Filters \(state.filters.count)", comment: "kind:button")
                        : String(localized: "Filters", comment: "kind:button"))
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(Text("Filters", comment: "kind:tooltip"))
        .accessibilityLabel(Text("Filters", comment: "kind:accessibility-label"))
        .accessibilityValue(Text("\(state.filters.count) on", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("countries.filters")
        .popover(isPresented: $state.isFiltersPresented, arrowEdge: .bottom) {
            PricesByCountryFiltersPopover(filters: $state.filters)
        }
    }
}
