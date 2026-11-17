//
//  FunnelChartView.swift
//  Atlas
//

import Charts
import SwiftUI

/// The selected step over time: the previous period shaded, the line, the
/// long-run average dashed, and a rule for each push from Atlas.
struct FunnelChartView: View {
    let chart: FunnelChart
    let onSelectChange: (MeasuredChange) -> Void

    var body: some View {
        Card(padding: Spacing.medium) {
            FlowLayout(spacing: Spacing.medium) {
                Text(chart.title).font(.headline)
                if chart.hasPrevious { legend(String(localized: "Previous period")) { Rectangle().fill(Palette.fill2) } }
                legend(String(localized: "This period")) { Rectangle().fill(Palette.accent).frame(height: 2) }
                if chart.average != nil {
                    legend(String(localized: "Average of everything kept")) { Rectangle().fill(Palette.label3).frame(height: 1) }
                }
                if !chart.marks.isEmpty {
                    legend(String(localized: "Pushed from Atlas")) { Rectangle().fill(Palette.label2).frame(width: 1) }
                }
            }
            if chart.isEmpty {
                Text(chart.gap?.chartText ?? String(localized: "Nothing to chart in these days."))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                plot
                    .frame(height: 170)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(chart.accessibilityText))
                marks
            }
            Text("Click a rate in the funnel to chart it. Click a change to see its result.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
        }
        .accessibilityIdentifier("analytics.funnel.chart")
    }

    private var plot: some View {
        Chart {
            if chart.hasPrevious, let first = chart.points.first, chart.points.indices.contains(chart.currentStart) {
                RectangleMark(
                    xStart: .value("Start", first.day.date),
                    xEnd: .value("End", chart.points[chart.currentStart].day.date),
                    yStart: .value("Low", chart.minimum),
                    yEnd: .value("High", chart.maximum)
                )
                .foregroundStyle(Palette.fill1)
            }
            ForEach(chart.points) { point in
                if let value = point.value {
                    LineMark(x: .value("Day", point.day.date), y: .value(chart.title, value))
                        .foregroundStyle(Palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.8))
                        .interpolationMethod(.monotone)
                }
            }
            if let average = chart.average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Palette.label3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(chart.marks) { mark in
                RuleMark(x: .value("Pushed", mark.day.date))
                    .foregroundStyle(Palette.label2)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartYScale(domain: chart.minimum...chart.maximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Palette.separator)
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(chart.text(number)).monospacedDigit() }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day())
            }
        }
    }

    /// The pushes on the timeline, as chips that open each one's result.
    @ViewBuilder
    private var marks: some View {
        if !chart.marks.isEmpty {
            FlowLayout(spacing: Spacing.xSmall) {
                ForEach(chart.marks.sorted { $0.date < $1.date }) { mark in
                    Button {
                        onSelectChange(mark)
                    } label: {
                        Text("\(AnalyticsText.day(mark.date)) · \(mark.shortTitle)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.mini)
                    .help("\(mark.title) · pushed from Atlas")
                    .accessibilityLabel(Text("\(AnalyticsText.day(mark.date)), \(mark.title). Open its result"))
                }
            }
        }
    }

    private func legend(_ title: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 5) {
            swatch().frame(width: 12, height: 8)
            Text(title).font(.caption).foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .combine)
    }
}
