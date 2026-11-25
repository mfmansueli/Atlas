//
//  CountryNameCell.swift
//  Atlas
//

import SwiftUI

/// The Country or region cell: the flag and name, the region under it, and
/// in a narrow table also how the price is set, its US dollars and what it
/// earns ("Automatic · ≈ $46 · you get ≈ $39") with Not pushed.
struct CountryNameCell: View {
    let row: CountryPriceRow
    var isNarrow = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            FlagTile(regionCode: row.territory.alpha2)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Spacing.xxSmall) {
                    Text(row.territory.name)
                        .atlasTextStyle(.body)
                        .lineLimit(1)
                    if row.isBase {
                        Pill(text: String(localized: "Base", comment: "kind:pill"))
                            .fixedSize()
                    }
                }
                Text(row.territory.region.title)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label3)
                    .lineLimit(1)
                if isNarrow {
                    HStack(spacing: Spacing.xxSmall) {
                        Text(foldedText)
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                        if row.isPending {
                            CountryNotPushedPill()
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Automatic · ≈ $46 · you get ≈ $39".
    private var foldedText: String {
        let parts = [row.source.title, row.dollarsText]
        guard row.proceeds != nil else { return parts.joined(separator: " · ") }
        return (parts + [String(localized: "you get \(row.proceedsText)", comment: "kind:hint")]).joined(separator: " · ")
    }
}
