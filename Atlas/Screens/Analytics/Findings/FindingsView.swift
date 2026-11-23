//
//  FindingsView.swift
//  Atlas
//

import SwiftUI

/// What to Try: the open findings, the ones acted on with their result,
/// and the dismissed ones.
struct FindingsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    /// Changes of the finding's area waiting in Review & Push.
    let waitingCount: (AnalyticsFinding) -> Int
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if viewModel.dataset.dayCount < 28, viewModel.findings.open.isEmpty, viewModel.findings.dismissed.isEmpty {
                    notYet
                } else {
                    header
                    switch viewModel.findingsFilter {
                    case .open: openList
                    case .actedOn: actedList
                    case .dismissed: dismissedList
                    }
                }
            }
            .padding(.bottom, Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("analytics.findings")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("What to try next").font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("From Atlas’s rules and your assistant, on the last 28 days. Each one opens the section where the fix is made.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.medium)
            AnalyticsSegments(
                label: String(localized: "Show"),
                plain: FindingsFilter.allCases.map { ($0, $0.title) },
                selection: $viewModel.findingsFilter,
                identifier: "analytics.findings.filter"
            )
        }
    }

    private var notYet: some View {
        let days = viewModel.dataset.dayCount
        let first = viewModel.dataset.firstDay.map { AnalyticsText.day($0.adding(28).date) }
        return ContentUnavailableView {
            Label("No findings yet", systemImage: "lightbulb")
        } description: {
            if let first {
                Text("Findings need a full 28 days to compare. \(viewModel.dataset.appName) has \(days); the first ones come around \(first).")
            } else {
                Text("Findings need a full 28 days to compare.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .accessibilityIdentifier("analytics.findings.none")
    }

    @ViewBuilder
    private var openList: some View {
        let findings = viewModel.openFindings
        if findings.isEmpty {
            Text("Nothing open. New findings appear when Apple’s next reports change something.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("analytics.findings.empty")
        }
        ForEach(findings) { finding in
            let waiting = waitingCount(finding)
            FindingCard(
                finding: finding,
                isNew: viewModel.findings.isNew(finding),
                state: waiting == 0 ? nil : waiting == 1
                    ? String(localized: "1 change in \(finding.area.title) is waiting in Review & Push, top right.")
                    : String(localized: "\(waiting) changes in \(finding.area.title) are waiting in Review & Push, top right.")
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
            Text("Nothing yet. A finding moves here once you’ve opened its section and pushed a change there; its result follows after 28 days.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
        }
        ForEach(findings) { finding in
            if let change = viewModel.actedChange(for: finding), let result = viewModel.results[change.id] {
                Card(padding: Spacing.medium) {
                    HStack(spacing: Spacing.small) {
                        FindingSourceMark(source: finding.source)
                        Pill(text: finding.area.title, style: .outline)
                        Pill(text: String(localized: "Acted on"))
                    }
                    Text(finding.title).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text("You pushed “\(change.title)” on \(AnalyticsText.day(change.date)). \(change.stageTitle):")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(result.beforeAfterText) · \(result.statusText)")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                    HStack {
                        Spacer()
                        Button("See the Result") { viewModel.show(change.id) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dismissedList: some View {
        let dismissed = viewModel.findings.dismissed
        if dismissed.isEmpty {
            Text("Nothing dismissed.").font(.callout).foregroundStyle(Palette.label2)
        } else {
            VStack(spacing: 0) {
                ForEach(dismissed) { item in
                    HStack(spacing: Spacing.small) {
                        FindingSourceMark(source: item.finding.source)
                        Text(item.finding.title).font(.callout).lineLimit(2)
                        Spacer(minLength: Spacing.small)
                        Text("Dismissed \(AnalyticsText.day(item.date))").font(.subheadline).foregroundStyle(Palette.label2)
                        Button("Restore") { viewModel.restore(item.id) }
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
            Text("A dismissed finding comes back only if its numbers change a lot.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }
}
