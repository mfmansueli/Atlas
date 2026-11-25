//
//  CountryProvenanceCell.swift
//  Atlas
//

import SwiftUI

/// Source: where the suggestion's factor came from (World Bank, IMF,
/// region median), with Fallback when the chosen index had no data.
struct CountryProvenanceCell: View {
    let row: CountryPriceRow

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            if let provenance = row.provenance {
                Text(Self.name(provenance))
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                if provenance.isFallback {
                    Pill(text: String(localized: "Fallback", comment: "kind:pill"), style: .outline)
                        .fixedSize()
                }
            } else {
                Text(verbatim: "—")
                    .foregroundStyle(Palette.label3)
            }
        }
        .help(row.provenance?.label ?? "")
        .accessibilityElement(children: .combine)
    }

    /// "World Bank", "IMF", "Region median".
    static func name(_ provenance: PriceProvenance) -> String {
        switch provenance.kind {
        case let .index(source): source.shortName
        default: provenance.badge
        }
    }
}
