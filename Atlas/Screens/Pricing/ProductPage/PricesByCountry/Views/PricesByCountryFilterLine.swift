//
//  PricesByCountryFilterLine.swift
//  Atlas
//

import SwiftUI

/// While Filters are on, one line says what they keep ("Europe · Increases
/// only · 2 of 40 shown") with Clear Filters.
struct PricesByCountryFilterLine: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text(text)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .monospacedDigit()
                .lineLimit(1)
                .accessibilityIdentifier("countries.filterLine.text")
            Button(String(localized: "Clear Filters", comment: "kind:button"), action: onClear)
                .plainButton()
                .accessibilityIdentifier("countries.filterLine.clear")
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.filterLine")
    }
}
