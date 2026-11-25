//
//  CountryProvenanceCell.swift
//  Atlas
//

import SwiftUI

/// Source: where the suggestion's factor came from, one pattern for every
/// row (board 76): "World Bank · 2025", "IMF · Oct 2026", "Region
/// median", with Fallback when the chosen index's exact figure was
/// missing, and "Uses Europe’s sales" when the country has too few sales
/// of its own. The help says why.
struct CountryProvenanceCell: View {
    let row: CountryPriceRow

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            if let provenance = row.provenance {
                Text(Self.name(provenance))
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .layoutPriority(1)
                if provenance.isFallback {
                    Pill(text: String(localized: "Fallback", comment: "kind:pill"), style: .outline)
                        .fixedSize()
                }
                if let pooled = row.evidence?.borrowedLine {
                    Text(verbatim: "· \(pooled)")
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text(verbatim: "—")
                    .foregroundStyle(Palette.label3)
            }
        }
        .help(Self.help(row))
        .accessibilityElement(children: .combine)
    }

    /// "World Bank · 2025", "IMF · Oct 2026", "Region median".
    static func name(_ provenance: PriceProvenance) -> String {
        PriceSourceText.text(provenance)
    }

    /// The source's detail, then why the country uses its region's sales.
    static func help(_ row: CountryPriceRow) -> String {
        [row.provenance?.detail, row.evidence?.borrowedTip].compactMap(\.self).joined(separator: "\n")
    }
}
