//
//  FunnelView.swift
//  Atlas
//

import SwiftUI

/// The Funnel view: the strip, what's missing, the biggest loss in words,
/// the timeline, and the first findings.
struct FunnelView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let report: FunnelReport
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                FunnelStrip(steps: report.steps, selected: viewModel.chart?.stage ?? viewModel.stage) { stage in
                    viewModel.stage = stage
                }
                if let note = report.note {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Image(systemName: report.noteIsWarning ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(report.noteIsWarning ? Palette.warningMark : Palette.label2)
                            .accessibilityHidden(true)
                        Text(note).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        // What the steps above say they need, with its fix.
                        if let gap = report.steps.compactMap(\.gap).first, let title = gap.actionTitle {
                            Button(title) {
                                viewModel.openSettings(focus: gap == .needsVendorNumber ? .vendorNumber : .salesRole)
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("analytics.funnel.fixGap")
                        }
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .background(report.noteIsWarning ? Palette.warningTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("analytics.funnel.note")
                }
                FunnelCalloutView(callout: report.callout) { action in
                    switch action {
                    case let .seeChange(id): viewModel.show(id)
                    case let .breakDown(dimension): viewModel.breakDown(by: dimension)
                    }
                }
                if let chart = viewModel.chart {
                    FunnelChartView(chart: chart) { viewModel.show($0.id) }
                }
                findings
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .accessibilityIdentifier("analytics.funnel")
    }

    @ViewBuilder
    private var findings: some View {
        let open = viewModel.openFindings
        if !open.isEmpty {
            HStack {
                Text("What to try next").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(open.count == 1 ? String(localized: "1 Finding") : String(localized: "All \(open.count) Findings")) { viewModel.tab = .findings }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accentText)
                    .font(.callout)
            }
            .padding(.top, Spacing.xSmall)
            ForEach(open.prefix(2)) { finding in
                FindingCard(finding: finding, isNew: viewModel.findings.isNew(finding)) {
                    viewModel.dismiss(finding)
                } onSecondAction: {
                    if let second = finding.secondAction { onAct(finding, second) }
                } onAction: {
                    onAct(finding, finding.action)
                }
            }
        }
    }
}
