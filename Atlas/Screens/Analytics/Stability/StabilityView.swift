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
    var release: StabilityReleaseActions = .none

    private static let widths: [CGFloat] = [80, 70, 70, 150]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if report.headline != nil {
                    StabilityBanner(report: report, actions: release)
                } else if !report.hasSessions {
                    noSessionsBanner
                }
                if report.hasSessions {
                    rates
                } else {
                    counts
                }
                if report.days.count > 1, report.hasSessions {
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
                            report.previous?.version ?? "—", String(localized: "Change", comment: "kind:column"),
                        ],
                        widths: Self.widths
                    )
                    ForEach(report.devices) { row in
                        Divider()
                        AnalyticsColumns(
                            [
                                AnyView(Text(row.device)),
                                AnyView(Text(report.hasSessions ? AnalyticsText.count(row.latest.sessions) : "—")),
                                AnyView(Text(value(row.latest))),
                                AnyView(Text(row.previous.map(value) ?? "—")),
                                AnyView(Text(row.changeText).foregroundStyle(row.comparison?.isHigher == true ? Palette.err : Palette.label)),
                            ],
                            widths: Self.widths
                        )
                    }
                }
                Text(footer)
                    .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(3)
                    .accessibilityIdentifier("analytics.stability.footer")
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .leavesChatRoom()
        .accessibilityIdentifier("analytics.stability")
    }

    /// Where the numbers come from (README-An2, November 25): the rate's
    /// two reports, or until when there are counts only.
    private var footer: String {
        guard report.hasSessions else {
            return String(localized: """
            Counts only until Apple’s App Sessions report includes \(report.latest.version), usually within 2 days. A sample: only \
            people who share analytics.
            """, comment: "kind:description")
        }
        return String(localized: """
        Crashes per 1,000 sessions, from Apple’s App Crashes and App Sessions reports. A sample: only people who share \
        analytics. Stack traces are in Xcode → Organizer.
        """, comment: "kind:description")
    }

    /// Crashes without sessions: counts, no rate and no verdict.
    private var noSessionsBanner: some View {
        Banner(
            kind: .info,
            title: String(localized: "No crash rate for \(report.latest.version) yet", comment: "kind:banner"),
            message: String(
                localized: "Apple sent crashes for \(report.latest.version) but no sessions, so these are counts: no rate, and no “better” or “worse”.",
                comment: "kind:description"
            ),
            isInline: true
        )
        .accessibilityIdentifier("analytics.stability.noSessions")
    }

    /// A version's crash rate, or its crash count without sessions.
    private func value(_ numbers: StabilityReport.VersionNumbers) -> String {
        report.hasSessions ? numbers.perThousand.map(AnalyticsText.perThousand) ?? "—" : AnalyticsText.count(numbers.crashes)
    }

    /// Crashes per 1,000 sessions against the version before.
    private var rates: some View {
        AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
            AnalyticsStat(
                label: String(localized: "Crashes per 1,000 sessions · \(report.latest.version)"),
                value: report.latest.perThousand.map(AnalyticsText.perThousand) ?? "—",
                note: report.previous.map { previous in
                    String(localized: "\(previous.version): \(previous.perThousand.map(AnalyticsText.perThousand) ?? "—") on the same days")
                } ?? "",
                valueColor: report.isWorse ? Palette.err : Palette.label,
                identifier: "analytics.stability.rate"
            )
            AnalyticsStat(
                label: report.previous.map { String(localized: "Against \($0.version)") }
                    ?? String(localized: "Against the version before", comment: "kind:other"),
                value: report.times.map(AnalyticsText.times) ?? "—",
                note: report.verdict
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
    }

    /// Without sessions: the crash counts of both versions; the banner
    /// above says why there's no rate (README-An2).
    private var counts: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
                AnalyticsStat(
                    label: String(localized: "Crashes · \(report.latest.version)", comment: "kind:label"),
                    value: AnalyticsText.count(report.latest.crashes),
                    note: report.period.text,
                    identifier: "analytics.stability.crashes"
                )
                if let previous = report.previous {
                    AnalyticsStat(
                        label: String(localized: "Crashes · \(previous.version)", comment: "kind:label"),
                        value: AnalyticsText.count(previous.crashes),
                        note: String(localized: "On the same days", comment: "kind:label")
                    )
                }
            }
        }
    }
}
