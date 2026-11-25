//
//  CountryFeelsLikeCell.swift
//  Atlas
//

import SwiftUI

/// Feels Like: the shown price for local incomes in US dollars and its
/// ratio to the US price ("$83 2.1×").
struct CountryFeelsLikeCell: View {
    let row: CountryPriceRow

    var body: some View {
        if let feels = row.feelsLike {
            HStack(spacing: Spacing.xxSmall) {
                Text(feels.valueText(row.shownPrice))
                    .atlasTextStyle(.callout)
                Text(feels.ratioText(row.shownPrice))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityElement(children: .combine)
        } else {
            Text(verbatim: "—")
                .foregroundStyle(Palette.label3)
        }
    }
}
