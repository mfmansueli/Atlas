//
//  PriceTestFactRow.swift
//  Atlas
//

import SwiftUI

/// One row of a price test card or confirmation: "Compared with" beside
/// "Asia Pacific, same 28 days, price unchanged."
struct PriceTestFactRow: View {
    let label: String
    let value: String
    var isProminent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            Text(label)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(width: Metrics.priceTestLabelWidth, alignment: .leading)
            Text(value)
                .atlasTextStyle(isProminent ? .headline : .callout)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
