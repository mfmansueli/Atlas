//
//  AnalyticsAfterChangesView.swift
//  Atlas
//

import SwiftUI

/// Analytics → After Changes (board 92): how each push from Atlas did,
/// against the weeks before it. A price change leads to Pricing → Results,
/// under a "From Analytics" bar that comes back here.
struct AnalyticsAfterChangesView: View {
    @Bindable var viewModel: AnalyticsViewModel
    /// Used without the main window's navigator (previews).
    let onOpenPricingResults: () -> Void

    /// Nil in previews without the main window.
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        ChangesView(viewModel: viewModel, onOpenPricing: openPricingResults)
    }

    private func openPricingResults() {
        guard let navigator else {
            onOpenPricingResults()
            return
        }
        let origin = AnalyticsOrigin(appID: viewModel.app.id, text: Self.pricingOrigin, tab: .afterChanges)
        navigator.follow(.pricingResults, origin: origin)
    }

    /// What the bar in Pricing says.
    static var pricingOrigin: String {
        String(localized: "Price results are in Pricing → Results, per territory.", comment: "kind:banner · From Analytics bar")
    }
}
