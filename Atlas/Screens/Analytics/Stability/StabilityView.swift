//
//  StabilityView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Stability: crashes of the newest version against the one
/// before on the same days, by device. A sample: people who share
/// analytics with developers.
struct StabilityView: View {
    let report: StabilityReport
    let onAct: (FindingAction, String) -> Void

    private static let widths: [CGFloat] = [90, 120, 120, 80]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let headline = report.headline {
                    AnalyticsNotice(tone: .warning, text: headline, identifier: "analytics.stability.alert")
                }
                AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
                    AnalyticsStat(
                        label: String(localized: "Crashes per 1,000 sessions · \(report.latest.version)"),
                        value: report.latest.perThousand.map(AnalyticsText.perThousand) ?? "—",
                        note: report.previous.map { previous in
                            String(localized: "\(previous.version): \(previous.perThousand.map(AnalyticsText.perThousand) ?? "—") on the same days")
                        } ?? "",
                        valueColor: report.isWorse ? Palette.danger : Palette.label,
                        identifier: "analytics.stability.rate"
                    )
                    AnalyticsStat(
                        label: String(localized: "Against \(report.previous?.version ?? "the version before")"),
                        value: report.times.map(AnalyticsText.times) ?? "—",
                        note: report.comparison.verdict
                    )
                    AnalyticsStat(
                        label: String(localized: "Sessions on \(report.latest.version)"),
                        value: AnalyticsText.count(report.latest.sessions),
                        note: report.period.text
                    )
                    AnalyticsStat(
                        label: String(localized: "Most affected device"),
                        value: report.mostAffected?.device ?? "—",
                        note: report.mostAffected?.times.map { String(localized: "\(AnalyticsText.times($0)) as often") } ?? ""
                    )
                }
                if report.days.count > 1 {
                    AnalyticsBox(
                        title: String(localized: "Crashes per 1,000 sessions, by day"),
                        trailing: [report.latest.version, report.previous?.version].compactMap(\.self).joined(separator: " · ")
                    ) {
                        StabilityDaysChart(days: report.days)
                            .frame(height: 160)
                            .padding(.horizontal, Spacing.medium)
                    }
                }
                AnalyticsBox(title: String(localized: "By device")) {
                    AnalyticsColumns(
                        titles: [
                            String(localized: "Device"), String(localized: "Sessions"), report.latest.version,
                            report.previous?.version ?? "—", String(localized: "Times"),
                        ],
                        widths: Self.widths
                    )
                    ForEach(report.devices) { row in
                        Divider()
                        AnalyticsColumns(
                            [
                                AnyView(Text(row.device)),
                                AnyView(Text(AnalyticsText.count(row.latest.sessions))),
                                AnyView(Text(row.latest.perThousand.map(AnalyticsText.perThousand) ?? "—")),
                                AnyView(Text(row.previous?.perThousand.map(AnalyticsText.perThousand) ?? "—")),
                                AnyView(Text(row.times.map(AnalyticsText.times) ?? "—").foregroundStyle((row.times ?? 0) > 1.5 ? Palette.danger : Palette.label)),
                            ],
                            widths: Self.widths
                        )
                    }
                }
                Text("""
                Crashes and sessions come from people who share analytics with developers, and Apple completes each day up to 5 days later. \
                Both versions are compared on the days both had sessions.
                """)
                    .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(3)
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .accessibilityIdentifier("analytics.stability")
    }
}
