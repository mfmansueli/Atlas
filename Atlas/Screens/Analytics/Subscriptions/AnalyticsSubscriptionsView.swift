//
//  AnalyticsSubscriptionsView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions (board 92): one summary page; Retention,
/// Offers and Billing and Plans open from it with "‹ Subscriptions".
struct AnalyticsSubscriptionsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (FindingAction, String) -> Void

    var body: some View {
        SubscriptionsPaneView(viewModel: viewModel, onAct: onAct) {
            ScrollView {
                ContentUnavailableView {
                    Label("No subscription numbers", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text(viewModel.dataset.salesState == .needsVendorNumber
                        ? String(localized: "Subscriptions come from Sales and Trends, which needs your vendor number.")
                        : String(localized: "Subscriptions come from Sales and Trends, which this key can’t read or hasn’t delivered yet."))
                } actions: {
                    Button("Analytics Settings…") {
                        viewModel.openSettings(focus: viewModel.dataset.salesState == .needsVendorNumber ? .vendorNumber : .salesRole)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xLarge)
            }
            .leavesChatRoom()
        }
    }
}
