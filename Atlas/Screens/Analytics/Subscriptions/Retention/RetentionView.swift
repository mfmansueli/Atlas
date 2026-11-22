//
//  RetentionView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions → Retention: what happens when people tap
/// Cancel Subscription, by message, against Apple's plain screen.
struct RetentionView: View {
    let report: RetentionReport?
    let appName: String
    let onAct: (FindingAction, String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let report, !report.isEmpty {
                    content(report)
                } else {
                    ContentUnavailableView {
                        Label("No one has opened Cancel Subscription yet", systemImage: "hand.raised")
                    } description: {
                        Text("Apple’s Retention Messaging report counts people who reach the cancel screen of \(appName)’s subscriptions. It shows here from the first one, up to 4 days later.")
                    } actions: {
                        Button("Open Retention") { onAct(.retention, String(localized: "No one has opened Cancel Subscription yet.")) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xLarge)
                    .accessibilityIdentifier("analytics.retention.empty")
                }
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .accessibilityIdentifier("analytics.retention")
    }

    @ViewBuilder
    private func content(_ report: RetentionReport) -> some View {
        if let arriving = report.arriving {
            AnalyticsNotice(
                tone: .info,
                text: String(localized: "\(AnalyticsText.day(arriving.first.date)) to \(AnalyticsText.day(arriving.last.date)) are still arriving: Apple completes each day up to 4 days later, so these numbers end \(AnalyticsText.day(report.period.last.date))."),
                identifier: "analytics.retention.arriving"
            )
        }
        AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
            AnalyticsStat(label: String(localized: "Opened Cancel Subscription"), value: AnalyticsText.count(report.opened), note: report.period.text)
            AnalyticsStat(label: String(localized: "Stayed"), value: AnalyticsText.count(report.stayed), note: String(localized: "Didn’t cancel"))
            AnalyticsStat(label: String(localized: "Canceled anyway"), value: AnalyticsText.count(report.canceled))
            Card(padding: Spacing.medium) {
                Text("Save rate").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
                RateLabel(rate: report.rate, font: .title3.weight(.semibold))
                Text(report.comparison.map { "\($0.pointsText) \($0.outcome.title)" } ?? report.rate.detail())
                    .font(.subheadline).foregroundStyle(Palette.label2).monospacedDigit().lineLimit(2)
            }
            .accessibilityIdentifier("analytics.retention.saveRate")
        }
        if report.weeks.count > 1 {
            AnalyticsBox(title: String(localized: "Save rate by week"), trailing: String(localized: "With a message · No Message")) {
                RetentionWeeksChart(weeks: report.weeks)
                    .frame(height: 160)
                    .padding(.horizontal, Spacing.medium)
            }
        }
        RetentionMessagesTable(report: report, onAct: onAct)
        AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
            AnalyticsBox(title: String(localized: "By subscription")) {
                AnalyticsColumns(titles: [String(localized: "Subscription"), String(localized: "Opened"), String(localized: "Save rate")], widths: [70, 110])
                ForEach(report.subscriptions) { row in
                    Divider()
                    AnalyticsColumns([AnyView(Text(row.name)), AnyView(Text(AnalyticsText.count(row.opened))), AnyView(RateLabel(rate: row.rate))], widths: [70, 110])
                }
            }
            AnalyticsBox(title: String(localized: "How they stayed"), trailing: AnalyticsText.count(report.saves)) {
                ForEach(report.saveTypes) { save in
                    ShareBarRow(name: save.name, count: save.count, share: save.share)
                }
                Spacer(minLength: Spacing.xSmall).frame(height: Spacing.xSmall)
            }
        }
        Text("Save rate = 1 − cancels ÷ people who opened the cancel screen. Apple completes each day up to 4 days later, so this ends \(AnalyticsText.day(report.period.last.date)). Retention Messaging counts every subscriber, not a sample.")
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .lineLimit(3)
    }
}
