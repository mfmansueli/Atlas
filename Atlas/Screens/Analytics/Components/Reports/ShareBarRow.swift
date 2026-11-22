//
//  ShareBarRow.swift
//  Atlas
//

import SwiftUI

/// A name, its count and share, over a thin bar: "Redeemed the offer · 41 · 44%".
struct ShareBarRow: View {
    let name: String
    var detail: String = ""
    let count: Int
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.callout)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Palette.label3).lineLimit(1)
                }
                Spacer(minLength: Spacing.small)
                Text("\(AnalyticsText.count(count)) · \(AnalyticsText.wholePercent(share))").font(.callout).monospacedDigit()
            }
            MeterBar(fraction: share, height: 4)
        }
        .padding(.horizontal, Spacing.medium)
        .accessibilityElement(children: .combine)
    }
}
