//
//  ChangeChartView.swift
//  Atlas
//

import Charts
import SwiftUI

/// The measured step around a push (board 92): the 28 days before shaded,
/// the daily rate as a line, and a rule on the day it was pushed.
struct ChangeChartView: View {
    let chart: ChangeChart

    var body: some View {
        Card(padding: Spacing.medium) {
            FlowLayout(spacing: Spacing.medium) {
                Text(chart.title).atlasTextStyle(.headline)
                legend(String(localized: "28 days before", comment: "kind:label · After Changes chart legend")) {
                    Rectangle().fill(Palette.fill2)
                }
                legend(String(localized: "Daily rate", comment: "kind:label · After Changes chart legend")) {
                    Rectangle().fill(Palette.accent).frame(height: 2)
                }
                legend(String(localized: "Pushed from Atlas", comment: "kind:label · After Changes chart legend")) {
                    Rectangle().fill(Palette.label2).frame(width: 1)
                }
            }
            plot
                .frame(height: ChangeResultLayout.chartHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(chart.accessibilityText))
        }
        .accessibilityIdentifier("analytics.changes.chart")
    }

    private var plot: some View {
        Chart {
            if let first = chart.points.first, chart.points.indices.contains(chart.afterStart) {
                RectangleMark(
                    xStart: .value("Start", first.day.date),
                    xEnd: .value("End", chart.points[chart.afterStart].day.date),
                    yStart: .value("Low", chart.minimum),
                    yEnd: .value("High", chart.maximum)
                )
                .foregroundStyle(Palette.fill1)
            }
            ForEach(chart.points) { point in
                if let value = point.value {
                    LineMark(x: .value("Day", point.day.date), y: .value(chart.title, value))
                        .foregroundStyle(Palette.accent)
                        .interpolationMethod(.monotone)
                }
            }
            RuleMark(x: .value("Pushed", chart.changeDay.date))
                .foregroundStyle(Palette.label2)
        }
        .chartYScale(domain: chart.minimum...chart.maximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Palette.separator)
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(AnalyticsText.percent(number)).monospacedDigit() }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day())
            }
        }
    }

    private func legend(_ title: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: Spacing.xSmall) {
            swatch().frame(width: Spacing.medium, height: Spacing.small)
            Text(title).atlasTextStyle(.subheadline).foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .combine)
    }
}
