//
//  PricesByCountryDisplayPicker.swift
//  Atlas
//

import SwiftUI

/// Table · Map · Histogram, as icons (tablecells, map, chart.bar.xaxis).
struct PricesByCountryDisplayPicker: View {
    @Bindable var state: PricesByCountryState

    var body: some View {
        Picker(String(localized: "View", comment: "kind:label"), selection: $state.display) {
            ForEach(PricingDisplay.allCases, id: \.self) { display in
                Image(systemName: display.systemImage)
                    .accessibilityLabel(Text(display.title))
                    .help(Text(display.title))
                    .tag(display)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("countries.display")
    }
}
