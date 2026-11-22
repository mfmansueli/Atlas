//
//  RetentionWeeksChart.swift
//  Atlas
//

import Charts
import SwiftUI

/// The weekly save rate with a message and with none.
struct RetentionWeeksChart: View {
    let weeks: [RetentionReport.Week]

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                if let value = week.withMessage {
                    LineMark(x: .value("Week", week.last.date), y: .value("Save rate", value), series: .value("Group", "with"))
                        .foregroundStyle(Palette.accentTint)
                        .symbol(.circle)
                }
                if let value = week.noMessage {
                    LineMark(x: .value("Week", week.last.date), y: .value("Save rate", value), series: .value("Group", "none"))
                        .foregroundStyle(Palette.label3)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .symbol(.circle)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let fraction = value.as(Double.self) { Text(AnalyticsText.wholePercent(fraction)) } }
            }
        }
        .accessibilityLabel(Text("Save rate by week, with a message and with no message"))
    }
}
