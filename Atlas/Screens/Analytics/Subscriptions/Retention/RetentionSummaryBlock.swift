//
//  RetentionSummaryBlock.swift
//  Atlas
//

import SwiftUI

/// Subscriptions → Summary's retention block: the save rate, with a message
/// or without, and how people stayed.
struct RetentionSummaryBlock: View {
    let report: RetentionReport
    let onOpen: () -> Void

    var body: some View {
        AnalyticsBox(title: String(localized: "Retention"), trailing: String(localized: "Through \(AnalyticsText.day(report.period.last.date))")) {
            AdaptiveGridLayout(minimumWidth: 220, spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save rate").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
                    RateLabel(rate: report.rate, font: .title2.weight(.semibold))
                    Text("\(AnalyticsText.count(report.stayed)) of \(AnalyticsText.count(report.opened)) stayed · \(report.rate.detail())")
                        .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(2).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("With a message, or without").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
                    bar(String(localized: "With a message"), rate: report.withMessage)
                    bar(String(localized: "No Message"), rate: report.noMessage)
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("How they stayed").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
                    ForEach(report.saveTypes) { save in
                        HStack {
                            Text(save.name).font(.callout)
                            Spacer()
                            Text(AnalyticsText.wholePercent(save.share)).font(.callout).monospacedDigit()
                        }
                        MeterBar(fraction: save.share, height: 4)
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            HStack {
                Spacer()
                Button("See Retention", action: onOpen).controlSize(.small).accessibilityIdentifier("analytics.subscriptions.seeRetention")
            }
            .padding(.horizontal, Spacing.medium)
        }
        .accessibilityIdentifier("analytics.subscriptions.retention")
    }

    private func bar(_ name: String, rate: AnalyticsRate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.callout)
                Spacer()
                RateLabel(rate: rate)
            }
            MeterBar(fraction: rate.fraction ?? 0, height: 4)
        }
        .accessibilityElement(children: .combine)
    }
}
