//
//  PriceTestStatusLine.swift
//  Atlas
//

import SwiftUI

/// Prices by Country while a test runs (board 76, `pt-run-prices`): "Europe
/// price test · day 9 of 28 · ends Dec 23, then the old prices come back",
/// with Show Test. A line, not a banner; no motion.
struct PriceTestStatusLine: View {
    let text: String
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "flask")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text(text)
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(Text(verbatim: text))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Show Test", comment: "kind:button"), action: onShow)
                .plainButton()
                .accessibilityIdentifier("countries.priceTest.show")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.priceTest")
    }
}
