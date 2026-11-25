//
//  BreakdownTrendChart.swift
//  Atlas
//

import Charts
import SwiftUI

/// The inspector's 90-day line of one row's page views per impression,
/// with the whole app's rate dashed.
struct BreakdownTrendChart: View {
    let trend: BreakdownRowTrend

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(String(localized: "Page views per impression, 90 days", comment: "kind:label"))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
            Chart {
                ForEach(trend.points) { point in
                    if let rate = point.rate {
                        LineMark(x: .value("Day", point.day.date), y: .value("Rate", rate))
                            .foregroundStyle(Palette.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.monotone)
                    }
                }
                if let average = trend.average {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(Palette.label3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: domain)
            .frame(height: 60)
            if let average = trend.average {
                Text(String(localized: "Dashed: the whole app, \(AnalyticsText.percent(average))", comment: "kind:label"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("analytics.breakdown.inspector.trend")
    }

    /// The rates' own range with a little room, not from zero: a line
    /// that moves between 4% and 6% would otherwise look flat.
    private var domain: ClosedRange<Double> {
        let values = trend.points.compactMap(\.rate) + [trend.average].compactMap(\.self)
        guard let low = values.min(), let high = values.max(), high > low else {
            let value = values.first ?? 0
            return max(0, value * 0.8)...max(value * 1.2, 0.0001)
        }
        let room = (high - low) * 0.15
        return max(0, low - room)...(high + room)
    }

    /// "Page views per impression over 90 days: from 5.1% to 4.4%; the whole app 5.4%."
    private var accessibilityText: String {
        let rates = trend.points.compactMap(\.rate)
        guard let first = rates.first, let last = rates.last else { return "" }
        let line = String(
            localized: "Page views per impression over 90 days: from \(AnalyticsText.percent(first)) to \(AnalyticsText.percent(last))",
            comment: "kind:accessibility-label"
        )
        guard let average = trend.average else { return line }
        return line + String(localized: "; the whole app \(AnalyticsText.percent(average))", comment: "kind:accessibility-label")
    }
}
