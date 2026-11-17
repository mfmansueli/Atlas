//
//  AnalyticsOverviewCard.swift
//  Atlas
//

import SwiftUI

/// Analytics on the overview: the funnel in one line, its weakest step and
/// the first finding, or where setup stands.
struct AnalyticsOverviewCard: View {
    let setup: AnalyticsSetup
    let report: FunnelReport?
    let topFinding: AnalyticsFinding?
    let onOpen: () -> Void

    var body: some View {
        Card {
            OverviewCardTitle(title: String(localized: "Analytics"), systemImage: AppWorkspaceSection.analytics.systemImage)
            switch setup {
            case .off:
                Text("Not turned on")
                    .font(.title3.weight(.semibold))
                Text("See where people drop off between the App Store and paying.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            case let .waiting(asked):
                Text("Apple is preparing the reports")
                    .font(.title3.weight(.semibold))
                Text("Asked \(AnalyticsText.day(asked)). They usually arrive in 1 to 2 days.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            case .keyCannotAsk:
                Text("Needs an Admin key")
                    .font(.title3.weight(.semibold))
                Text("Only an Admin key can ask Apple for reports.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            case .ready:
                ready
            }
            Button(setup == .off ? String(localized: "Set Up Analytics") : String(localized: "Open Analytics"), action: onOpen)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("overview.analyticsCard.open")
        }
        .accessibilityIdentifier("overview.analyticsCard")
    }

    @ViewBuilder
    private var ready: some View {
        if let report {
            Text(Self.line(report))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(report.callout.title)
                .font(.subheadline)
                .foregroundStyle(report.callout.isLoss ? Palette.warning : Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if let topFinding {
                OverviewRow {
                    Text(topFinding.title).lineLimit(2)
                } value: {
                    Pill(text: topFinding.area.title, style: .outline)
                }
            }
        } else {
            Text("No numbers yet")
                .font(.title3.weight(.semibold))
        }
    }

    /// "184,200 → 9,870 → 3,120 → 412 → 168", the steps that have a count.
    static func line(_ report: FunnelReport) -> String {
        report.steps.compactMap { $0.count.map(AnalyticsText.count) }.joined(separator: " → ")
    }
}
