//
//  CountryPriceButton.swift
//  Atlas
//

import SwiftUI

/// The Price cell: a pop-up-style button with the shown price that opens
/// the price popover.
struct CountryPriceButton: View {
    let row: CountryPriceRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxSmall) {
                Text(row.shownPriceText)
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(Text("Change this price", comment: "kind:help"))
        .accessibilityLabel(Text("Change the price in \(row.territory.name), now \(row.shownPriceText)", comment: "kind:label"))
        .accessibilityIdentifier("countries.price.\(row.id)")
    }
}
