//
//  PricesByCountryToolbar.swift
//  Atlas
//

import SwiftUI

/// Above the table (board 73): Find a country, region or currency; All ·
/// Suggested · Set by You · Automatic with counts; Filters with its count;
/// Columns; and Table · Map · Histogram. At 860 × 560 the counts hide and
/// Filters and Columns are icons. The row stacks when it can't fit.
struct PricesByCountryToolbar: View {
    @Binding var search: String
    @Binding var filter: PricesByCountryFilter
    let counts: [PricesByCountryFilter: Int]
    let state: PricesByCountryState
    var isCompact = false
    /// Optional columns hide in a narrow table; the Columns menu goes too.
    var showsColumns = true
    /// Shown where the banner isn't (Keep Prices, nothing suggested).
    var strategy: AnyView?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                find.frame(maxWidth: Metrics.countriesFindFieldWidth)
                segments
                Spacer(minLength: 0)
                trailing
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    find
                    trailing
                }
                segments
            }
        }
    }

    private var trailing: some View {
        HStack(spacing: Spacing.small) {
            if let strategy { strategy }
            PricesByCountryFiltersButton(state: state, isCompact: isCompact)
            if showsColumns, state.display == .table {
                PricesByCountryColumnsMenu(state: state, isCompact: isCompact)
            }
            PricesByCountryDisplayPicker(state: state)
        }
        .fixedSize()
    }

    private var find: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return HStack(spacing: Spacing.xSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            TextField(String(localized: "Find a country, region or currency", comment: "kind:placeholder"), text: $search)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("countries.find")
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.label3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear", comment: "kind:button"))
                .accessibilityIdentifier("countries.find.clear")
            }
        }
        .atlasTextStyle(.body)
        .padding(.horizontal, Spacing.small)
        .frame(minWidth: Metrics.countriesFindFieldMinimumWidth)
        .frame(height: Metrics.menuFieldHeight)
        .background(Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
    }

    private var segments: some View {
        FittingSegmentedPicker(
            label: String(localized: "Show", comment: "kind:label"),
            options: PricesByCountryFilter.allCases.map { ($0, isCompact ? $0.title : "\($0.title) \(counts[$0] ?? 0)") },
            selection: $filter
        )
        .fixedSize()
        .accessibilityIdentifier("countries.filter")
    }
}
