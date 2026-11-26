//
//  AnalyticsStabilityView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Stability (board 92): crashes by version and "Open Version
/// 1.4". Until Apple's crash numbers have something to show, the view is
/// the case's empty state (`CrashesSoFar` has the rules), the same case
/// its card in the strip says.
struct AnalyticsStabilityView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let release: StabilityReleaseActions

    var body: some View {
        if let empty = viewModel.stabilityEmptyContent {
            AnalyticsTabEmptyView(content: empty, systemImage: AnalyticsTab.stability.systemImage, identifier: "analytics.stability.empty") { action in
                if case .openVersion = action { release.openVersion() }
            }
        } else if let report = viewModel.stability {
            StabilityView(report: report, release: release)
        }
    }
}
