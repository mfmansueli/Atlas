//
//  FindingsView.swift
//  Atlas
//

import SwiftUI

/// What to Try (board 92): the open findings (new ones marked, and the ones
/// whose change waits in Review & Push saying so), the ones acted on with
/// their result, and the dismissed ones. Each finding's button opens the
/// section where the change is made, under a "From Analytics" bar. With
/// none yet, a small empty state says why.
struct FindingsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    /// Changes of the finding's area waiting in Review & Push.
    let waitingCount: (AnalyticsFinding) -> Int
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                let state = viewModel.findingsListState
                if state == .list {
                    header
                    switch viewModel.findingsFilter {
                    case .open: openList
                    case .actedOn: actedList
                    case .dismissed: dismissedList
                    }
                } else {
                    EmptyStateView(
                        state.title, systemImage: AnalyticsTab.whatToTry.systemImage, text: state.text(appName: viewModel.dataset.appName), size: .inline
                    )
                    .accessibilityIdentifier("analytics.findings.none")
                }
            }
            .padding(.bottom, Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .leavesChatRoom()
        .accessibilityIdentifier("analytics.findings")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(FindingsText.heading(count: viewModel.findingsCount(.open), days: FindingsListState.fullPeriod))
                    .atlasTextStyle(.title3)
                    .accessibilityAddTraits(.isHeader)
                Text(FindingsText.subheading)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.medium)
            AnalyticsSegments(
                label: String(localized: "Show", comment: "kind:label · What to Try filter"),
                plain: FindingsFilter.allCases.map { ($0, title(of: $0)) },
                selection: $viewModel.findingsFilter,
                identifier: "analytics.findings.filter"
            )
        }
    }

    /// "Open · 3": each view with how many it holds.
    private func title(of filter: FindingsFilter) -> String {
        String(localized: "\(filter.title) · \(viewModel.findingsCount(filter))", comment: "kind:segment · What to Try filter")
    }

    @ViewBuilder
    private var openList: some View {
        let findings = viewModel.openFindings
        if findings.isEmpty {
            Text("Nothing open. New findings come with Apple’s next reports.", comment: "kind:empty-state · What to Try")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("analytics.findings.empty")
        }
        ForEach(findings) { finding in
            FindingCard(
                finding: finding,
                isNew: viewModel.findings.isNew(finding),
                state: FindingsText.waiting(count: waitingCount(finding), area: finding.area)
            ) {
                viewModel.dismiss(finding)
            } onSecondAction: {
                if let second = finding.secondAction { onAct(finding, second) }
            } onAction: {
                onAct(finding, finding.action)
            }
        }
    }

    @ViewBuilder
    private var actedList: some View {
        let findings = viewModel.actedFindings
        if findings.isEmpty {
            Text("Nothing yet. Push a change from a finding’s section; its result shows after 28 days.", comment: "kind:empty-state · What to Try")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
        }
        ForEach(findings) { finding in
            if let change = viewModel.actedChange(for: finding), let result = viewModel.results[change.id] {
                Card(padding: Spacing.medium) {
                    HStack(spacing: Spacing.small) {
                        FindingSourceMark(source: finding.source)
                        Pill(text: finding.area.title, style: .outline)
                        Pill(text: String(localized: "Acted on", comment: "kind:pill · What to Try"))
                    }
                    Text(finding.title).atlasTextStyle(.headline).fixedSize(horizontal: false, vertical: true)
                    Text("You pushed “\(change.title)” on \(AnalyticsText.day(change.date)). \(change.stageTitle):", comment: "kind:description · What to Try")
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(result.beforeAfterText) · \(result.statusText)")
                        .atlasTextStyle(.headline)
                        .monospacedDigit()
                    HStack {
                        Spacer()
                        Button(String(localized: "See the Result", comment: "kind:button · What to Try")) { viewModel.show(change.id) }
                            .rowActionButton()
                            .accessibilityIdentifier("analytics.findings.seeResult")
                    }
                }
                .accessibilityIdentifier("analytics.findings.acted.\(finding.id)")
            }
        }
    }

    @ViewBuilder
    private var dismissedList: some View {
        let dismissed = viewModel.findings.dismissed
        if dismissed.isEmpty {
            Text("Nothing dismissed.", comment: "kind:empty-state · What to Try").atlasTextStyle(.callout).foregroundStyle(Palette.label2)
        } else {
            VStack(spacing: 0) {
                ForEach(dismissed) { item in
                    HStack(spacing: Spacing.small) {
                        FindingSourceMark(source: item.finding.source)
                        Text(item.finding.title).atlasTextStyle(.callout).lineLimit(2)
                        Spacer(minLength: Spacing.small)
                        Text("Dismissed \(AnalyticsText.day(item.date))", comment: "kind:status · What to Try")
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label2)
                        Button(String(localized: "Restore", comment: "kind:button · What to Try")) { viewModel.restore(item.id) }
                            .controlSize(.regular)
                            .accessibilityIdentifier("analytics.findings.restore")
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    if item.id != dismissed.last?.id { Divider() }
                }
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
            Text("A dismissed finding comes back only if its numbers change a lot.", comment: "kind:hint · What to Try")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }
}
