//
//  AnalyticsTabStrip.swift
//  Atlas
//

import SwiftUI

/// The strip of Analytics' views under the header (board 92): icon, name
/// and one short summary each ("Fewer page views · crashes up", "3 new to
/// try"). A view with no data yet says its case ("None sold yet").
struct AnalyticsTabStrip: View {
    @Bindable var viewModel: AnalyticsViewModel

    var body: some View {
        PageCardStrip(
            items: viewModel.tabs.map(item),
            selection: $viewModel.tab,
            label: String(localized: "Analytics views", comment: "kind:label · VoiceOver name of the strip"),
            identifier: "analytics.tab"
        )
    }

    private func item(_ tab: AnalyticsTab) -> PageCardItem<AnalyticsTab> {
        let summary = viewModel.summary(for: tab)
        return PageCardItem(
            id: tab,
            title: tab.title,
            systemImage: tab.systemImage,
            status: summary.text.isEmpty ? nil : summary.text,
            tone: summary.tone,
            identifier: tab.rawValue
        )
    }
}
