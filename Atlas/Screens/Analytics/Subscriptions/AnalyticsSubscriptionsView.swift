//
//  AnalyticsSubscriptionsView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions (board 92): one summary page; Retention,
/// Offers and Billing and Plans open from it with "‹ Subscriptions". Until
/// Apple's subscription reports have something to count, the summary is
/// the case's empty state (`SubscriptionsSoFar` has the rules), the same
/// case its card in the strip says.
struct AnalyticsSubscriptionsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (FindingAction, String) -> Void

    var body: some View {
        if viewModel.subscriptionsPane == .summary, let empty = viewModel.subscriptionsEmptyContent {
            AnalyticsTabEmptyView(
                content: empty, systemImage: AnalyticsTab.subscriptions.systemImage, identifier: "analytics.subscriptions.empty"
            ) { action in
                if action == .openPricing { onAct(.pricing(territory: nil), empty.title) }
            }
        } else {
            SubscriptionsPaneView(viewModel: viewModel, onAct: onAct) {
                ScrollView {
                    EmptyStateView(
                        String(localized: "No subscription numbers", comment: "kind:empty-title · Analytics → Subscriptions without sales"),
                        systemImage: AnalyticsTab.subscriptions.systemImage,
                        text: salesText,
                        size: .inline
                    ) {
                        Button(String(localized: "Analytics Settings…", comment: "kind:button")) {
                            viewModel.openSettings(focus: viewModel.dataset.salesState == .needsVendorNumber ? .vendorNumber : .salesRole)
                        }
                        .secondaryButton()
                    }
                    .accessibilityIdentifier("analytics.subscriptions.noSales")
                }
                .leavesChatRoom()
            }
        }
    }

    /// Why there are no subscription numbers without Sales and Trends.
    private var salesText: String {
        viewModel.dataset.salesState == .needsVendorNumber
            ? String(localized: "Subscriptions come from Sales and Trends, which needs your vendor number.", comment: "kind:description")
            : String(localized: "Subscriptions come from Sales and Trends, which this key can’t read or hasn’t delivered yet.", comment: "kind:description")
    }
}
