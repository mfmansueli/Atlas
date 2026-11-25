//
//  SubscriptionsPaneView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions: Summary (Sales and Trends, with the cancel
/// screen and billing on top), Retention, Offers, and Billing and Plans.
struct SubscriptionsPaneView<Unavailable: View>: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (FindingAction, String) -> Void
    /// What Summary shows without Sales and Trends.
    @ViewBuilder var unavailable: () -> Unavailable

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnalyticsSegments(
                label: String(localized: "Subscriptions"),
                plain: SubscriptionsPane.allCases.map { ($0, $0.title) },
                selection: $viewModel.subscriptionsPane,
                identifier: "analytics.subscriptions.pane"
            )
            switch viewModel.subscriptionsPane {
            case .summary:
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
}
