//
//  AnalyticsAfterChangesView.swift
//  Atlas
//

import SwiftUI

/// Analytics → After Changes (board 92): how each push from Atlas did,
/// against the weeks before it.
struct AnalyticsAfterChangesView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onOpenPricingResults: () -> Void

    var body: some View {
        ChangesView(viewModel: viewModel, onOpenPricing: onOpenPricingResults)
    }
}
