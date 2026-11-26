//
//  AnalyticsOverviewView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Overview (board 92): four KPIs the funnel doesn't show, the
/// funnel from impression to paid, the biggest loss, the daily chart,
/// What to try next and the last push.
struct AnalyticsOverviewView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let report: FunnelReport
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        FunnelView(viewModel: viewModel, report: report, onAct: onAct)
    }
}
