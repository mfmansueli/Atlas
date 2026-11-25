//
//  CountryPriceMapTileButton.swift
//  Atlas
//

import SwiftUI

/// One map tile: the country's code and its feels-like ratio on its price
/// level's colour; an `aiFill` ring where a suggestion waits.
struct CountryPriceMapTileButton: View {
    let tile: CountryPriceMapTile
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
        Button(action: action) {
            VStack(spacing: 0) {
                Text(tile.code)
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                Text(tile.ratioText)
                    .atlasTextStyle(.subheadline)
                    .monospacedDigit()
            }
            .foregroundStyle(tile.level?.label ?? Palette.label2)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity, minHeight: Metrics.countriesMapTile)
            .background(tile.level?.fill ?? Palette.fill2, in: shape)
            .overlay {
                if tile.hasSuggestion {
                    shape.strokeBorder(Palette.aiFill, lineWidth: 2)
                } else if contrast == .increased {
                    shape.strokeBorder(Palette.separator2, lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(Text(tile.accessibilityText))
        .accessibilityLabel(Text(tile.accessibilityText))
        .accessibilityValue(tile.hasSuggestion ? Text("Suggestion waiting", comment: "kind:accessibility-label") : Text(verbatim: ""))
        .accessibilityIdentifier("countries.map.tile.\(tile.id)")
    }
}
