//
//  StabilityDaysChart.swift
//  Atlas
//

import Charts
import SwiftUI

/// Crashes per 1,000 sessions a day, for the newest version and the one before.
struct StabilityDaysChart: View {
    let days: [StabilityReport.Day]

    var body: some View {
        Chart {
            ForEach(days) { day in
                if let value = day.latest {
                    LineMark(x: .value("Day", day.day.date), y: .value("Crashes", value), series: .value("Version", "latest"))
                        .foregroundStyle(Palette.errMark)
                }
                if let value = day.previous {
                    LineMark(x: .value("Day", day.day.date), y: .value("Crashes", value), series: .value("Version", "previous"))
                        .foregroundStyle(Palette.label3)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
        }
        .accessibilityLabel(Text("Crashes per 1,000 sessions by day"))
    }
}
