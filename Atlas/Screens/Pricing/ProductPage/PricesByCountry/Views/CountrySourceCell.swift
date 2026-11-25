//
//  CountrySourceCell.swift
//  Atlas
//

import SwiftUI

/// How it's set: Base price, Automatic, Set by you or Accepted suggestion,
/// with Not pushed while a change waits.
struct CountrySourceCell: View {
    let row: CountryPriceRow

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(row.sourceText)
                .atlasTextStyle(.callout)
                .foregroundStyle(row.source == .automatic ? Palette.label2 : Palette.label)
                .lineLimit(1)
            if row.isPending {
                CountryNotPushedPill()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
