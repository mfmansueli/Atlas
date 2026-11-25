//
//  RetentionSaveRateLine.swift
//  Atlas
//

import SwiftUI

/// A message's save rate over 28 days, under its name in the list, with its
/// verdict against No Message.
struct RetentionSaveRateLine: View {
    let measured: RetentionReport.Message?

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text("Save rate · 28 days").foregroundStyle(Palette.label2)
            if let measured, measured.opened > 0 {
                RateLabel(rate: measured.rate)
                Text("· \(AnalyticsText.count(measured.stayed)) of \(AnalyticsText.count(measured.opened))").foregroundStyle(Palette.label2)
                if let outcome = measured.againstNoMessage {
                    Text("· \(outcome.verdict)")
                        .foregroundStyle(RateLabel.verdictColor(for: outcome.standing))
                }
            } else {
                Text("— · No one has opened Cancel Subscription yet").foregroundStyle(Palette.label2)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}
