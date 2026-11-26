//
//  AnalyticsKPIRow.swift
//  Atlas
//

import SwiftUI

/// The Overview's four numbers the funnel doesn't show: as many in a row
/// as fit, every row as tall as its tallest card.
struct AnalyticsKPIRow: View {
    let numbers: [AnalyticsKPI]
    let onOpen: (AnalyticsKPI.Kind) -> Void

    var body: some View {
        AdaptiveGridLayout(minimumWidth: Metrics.analyticsKPIMinWidth, spacing: Spacing.small) {
            ForEach(numbers) { number in
                AnalyticsKPICard(number: number) { onOpen(number.kind) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Key numbers", comment: "kind:accessibility-label · Analytics Overview's four numbers"))
        .accessibilityIdentifier("analytics.kpis")
    }
}
