//
//  CountryPriceMapLegend.swift
//  Atlas
//

import SwiftUI

/// The map's key: the five price levels, from much cheaper to much pricier
/// for local incomes than in the US, and the suggestion ring.
struct CountryPriceMapLegend: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(PriceLevel.allCases, id: \.self) { level in
                HStack(spacing: Spacing.xxSmall) {
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .fill(level.fill)
                        .frame(width: Spacing.medium, height: Spacing.medium)
                    Text(level.legend)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
            }
            HStack(spacing: Spacing.xxSmall) {
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .strokeBorder(Palette.aiFill, lineWidth: 2)
                    .frame(width: Spacing.medium, height: Spacing.medium)
                Text("Suggestion", comment: "kind:field-label")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("countries.map.legend")
    }
}
