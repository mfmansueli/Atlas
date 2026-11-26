//
//  SubscriptionsPaneView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions (README-DS §16, board 92): one summary page
/// (Sales and Trends, with the cancel screen, billing and offers on it);
/// Retention, Offers and Billing and Plans open from it under
/// "‹ Subscriptions", which goes back. Two levels at most.
struct SubscriptionsPaneView<Unavailable: View>: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (FindingAction, String) -> Void
    /// What the summary shows without Sales and Trends.
    @ViewBuilder var unavailable: () -> Unavailable

    var body: some View {
        switch viewModel.subscriptionsPane {
        case .summary:
            summary
        case let pane:
            VStack(alignment: .leading, spacing: Spacing.medium) {
                SubscriptionsBackBar(pane: pane) { viewModel.subscriptionsPane = .summary }
                detail(pane)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        if let report = viewModel.subscriptions {
            SubscriptionsView(
                report: report, appName: viewModel.app.name, liveRetentionMessages: viewModel.context.liveRetentionMessages,
                retention: viewModel.retention, lifecycle: viewModel.lifecycle, gracePeriod: viewModel.gracePeriod,
                hasPageRows: viewModel.reports.hasPageRows,
                onShow: { viewModel.subscriptionsPane = $0 },
                onBreakDown: { viewModel.breakDown(by: .productPage) },
                onAct: onAct
            )
        } else {
            unavailable()
        }
    }

    @ViewBuilder
    private func detail(_ pane: SubscriptionsPane) -> some View {
        switch pane {
        case .summary:
            EmptyView()
        case .retention:
            RetentionView(report: viewModel.retention, appName: viewModel.app.name, onAct: onAct)
        case .offers:
            OffersView(report: viewModel.lifecycle, onAct: onAct)
        case .billing:
            let suggestions = GracePeriodSuggestionStore.shared
            BillingView(
                report: viewModel.lifecycle, gracePeriod: viewModel.gracePeriod, appName: viewModel.app.name,
                onTurnOn: { duration in
                    try await viewModel.turnOnGracePeriod(duration)
                    suggestions.remove(for: viewModel.app.id)
                },
                suggestion: suggestions.suggestion(for: viewModel.app.id),
                onDismissSuggestion: { suggestions.remove(for: viewModel.app.id) }
            )
        }
    }
}
