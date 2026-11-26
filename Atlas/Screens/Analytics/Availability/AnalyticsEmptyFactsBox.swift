//
//  AnalyticsEmptyFactsBox.swift
//  Atlas
//

import SwiftUI

/// The key/value lines under an Analytics empty state ("Reports start" ·
/// "The day after the first sale"), in a raised box as wide as the
/// sentences above it. Each line reads as one in VoiceOver.
struct AnalyticsEmptyFactsBox: View {
    let facts: [AnalyticsEmptyFact]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                if index > 0 {
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    Text(fact.label)
                        .foregroundStyle(Palette.label)
                        .lineLimit(2)
                    Text(fact.value)
                        .foregroundStyle(Palette.label2)
                        .monospacedDigit()
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Spacing.small)
                .accessibilityElement(children: .combine)
            }
        }
        .atlasTextStyle(.callout)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, Spacing.medium)
        .frame(maxWidth: Metrics.emptyStateTextWidth, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.empty.facts")
    }
}
