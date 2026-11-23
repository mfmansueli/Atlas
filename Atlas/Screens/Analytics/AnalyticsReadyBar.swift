//
//  AnalyticsReadyBar.swift
//  Atlas
//

import SwiftUI

/// Under the header once there are numbers: the five views, the days
/// compared, and how fresh Apple's data is.
struct AnalyticsReadyBar: View {
    @Bindable var viewModel: AnalyticsViewModel
    let funnel: FunnelReport

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FlowLayout(spacing: Spacing.medium) {
                AnalyticsSegments(
                    label: String(localized: "Analytics view"),
                    options: viewModel.tabs.map { tab in
                        (tab, tab.title, tab == .findings && viewModel.tab != .findings ? viewModel.findings.newCount : 0)
                    },
                    selection: $viewModel.tab,
                    identifier: "analytics.tab"
                )
                HStack(spacing: Spacing.small) {
                    Text(funnel.rangeText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                    if viewModel.activity.isLoading {
                        ProgressView().controlSize(.small)
                        Text("Checking…").font(.subheadline).foregroundStyle(Palette.label2)
                    } else if let checked = viewModel.lastChecked {
                        Text("Checked \(AnalyticsText.moment(checked, now: viewModel.store.now()))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                            .help(checkedHelp)
                            .accessibilityIdentifier("analytics.lastChecked")
                    }
                    Button {
                        viewModel.isReportsPresented = true
                    } label: {
                        Pill(
                            text: String(localized: "Data through \(AnalyticsText.day(funnel.period.last.date))"),
                            style: viewModel.staleDays == nil ? .outline : .warning
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Reports from Apple: what each one adds, and where it stands")
                    .accessibilityIdentifier("analytics.dataThrough")
                }
            }
            if let behind = viewModel.staleDays {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Image(systemName: "clock").foregroundStyle(Palette.warnMark).accessibilityHidden(true)
                    Text(staleText(behind)).font(.callout).lineLimit(3)
                    Spacer(minLength: Spacing.small)
                    Button("Check Again") { Task { await viewModel.refresh(force: true) } }
                        .controlSize(.regular)
                        .disabled(viewModel.activity.isLoading)
                        .accessibilityIdentifier("analytics.checkAgain")
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("analytics.stale")
            }
        }
    }

    /// When Apple was asked, and that Refresh checks again.
    private var checkedHelp: String {
        let refresh = String(localized: "Refresh (⌘R) checks again.")
        guard let asked = viewModel.askedOn else { return refresh }
        return String(localized: "Apple was asked for these reports \(AnalyticsText.moment(asked, now: viewModel.store.now())).") + " " + refresh
    }

    private func staleText(_ behind: Int) -> String {
        let newest = AnalyticsText.day(funnel.period.last.date)
        let base = String(localized: "Apple’s reports are usually 1 to 2 days behind. These are \(behind) days behind: the newest data is from \(newest).")
        guard let checked = viewModel.store.record(for: viewModel.app.id).lastChecked else { return base }
        return base + " " + String(localized: "Last checked \(AnalyticsText.moment(checked, now: viewModel.store.now())).")
    }
}
