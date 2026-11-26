//
//  AnalyticsStabilityView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Stability (board 92): crashes by version and "Open Version
/// 1.4".
struct AnalyticsStabilityView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let release: StabilityReleaseActions

    var body: some View {
        if let report = viewModel.stability {
            StabilityView(report: report, release: release)
        }
    }
}
