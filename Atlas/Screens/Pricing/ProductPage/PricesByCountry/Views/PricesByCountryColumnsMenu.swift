//
//  PricesByCountryColumnsMenu.swift
//  Atlas
//

import SwiftUI

/// Columns (board 73, `pr-prod-cols`): show or hide In US$, Proceeds, How
/// it's set, Feels Like, Equalized, Currency, Source and Reason. Country,
/// Price and Change always show. An icon at 860 × 560.
struct PricesByCountryColumnsMenu: View {
    let state: PricesByCountryState
    var isCompact = false

    var body: some View {
        Menu {
            ForEach(PricesByCountryColumn.optional) { column in
                Toggle(column.title, isOn: Binding(
                    get: { state.isShown(column) },
                    set: { state.setShown(column, $0) }
                ))
                .accessibilityIdentifier("countries.columns.\(column.rawValue)")
            }
            Divider()
            Button(String(localized: "Show Default Columns", comment: "kind:menu-item")) {
                state.columns = PricesByCountryState.defaultColumns
            }
        } label: {
            if isCompact {
                Image(systemName: "tablecells.badge.ellipsis")
            } else {
                Label(String(localized: "Columns", comment: "kind:button"), systemImage: "tablecells.badge.ellipsis")
                    .labelStyle(.titleAndIcon)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .fixedSize()
        .help(Text("Columns", comment: "kind:help"))
        .accessibilityLabel(Text("Columns", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("countries.columns")
    }
}
