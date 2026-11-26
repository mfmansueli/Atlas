//
//  AnalyticsOverviewView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Overview (board 92), top to bottom: four numbers the funnel
/// doesn't show, the funnel from impression to paid, the biggest loss, the
/// daily chart with the pushes on it, What to try next and the last push.
struct AnalyticsOverviewView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let report: FunnelReport
    /// The Rating number; nil before (or without) ratings.
    var rating: OverviewRating?
    var isRatingLoading = false
    /// Rating's blue line: Ratings & Reviews.
    var onOpenReviews: () -> Void = {}
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                AnalyticsKPIRow(numbers: viewModel.kpis(rating: rating, isRatingLoading: isRatingLoading)) { kind in
                    if !viewModel.open(kind), kind == .rating { onOpenReviews() }
                }
                OverviewFunnel(
                    steps: viewModel.funnelSteps,
                    selected: viewModel.chart?.stage ?? viewModel.stage,
                    note: viewModel.funnelNote
                ) { step in
                    viewModel.select(step)
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
                OverviewFindings(viewModel: viewModel, onAct: onAct)
                if let last = viewModel.lastPush {
                    OverviewLastPush(summary: last) {
                        viewModel.show(last.changeID)
                    } onAll: {
                        viewModel.tab = .afterChanges
                    }
                }
                if viewModel.afterDownload != nil || viewModel.webPreview != nil {
                    FunnelMoreView(afterDownload: viewModel.afterDownload, webPreview: viewModel.webPreview)
                }
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .leavesChatRoom()
        .accessibilityIdentifier("analytics.overview")
    }
}
