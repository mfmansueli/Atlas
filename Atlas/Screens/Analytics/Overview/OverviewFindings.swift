//
//  OverviewFindings.swift
//  Atlas
//

import SwiftUI

/// "What to try next" on the Overview: the first two open findings, and
/// the way to all of them.
struct OverviewFindings: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        let open = viewModel.openFindings
        let all = open.count == 1
            ? String(localized: "1 Finding", comment: "kind:button · Analytics Overview: opens What to Try")
            : String(localized: "All \(open.count) Findings", comment: "kind:button · Analytics Overview: opens What to Try")
        if !open.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text("What to try next", comment: "kind:heading · Analytics Overview")
                        .atlasTextStyle(.title3)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Spacing.small)
                    Button(all) { viewModel.tab = .whatToTry }
                        .plainButton()
                        .accessibilityIdentifier("analytics.overview.allFindings")
                }
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
}
