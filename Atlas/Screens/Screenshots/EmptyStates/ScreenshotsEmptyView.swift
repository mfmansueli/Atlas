//
//  ScreenshotsEmptyView.swift
//  Atlas
//

import SwiftUI

/// No screenshots yet (board 74 · 4): Add Screenshots… is the toolbar's
/// page action (board 80) and Make Screenshots… is Autopilot's, both named
/// in the sentence. No button of its own: both are already on screen.
struct ScreenshotsEmptyView: View {
    @Bindable var viewModel: ScreenshotsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(subtitle: String(
                localized: "Images people swipe through on the App Store, per language and device.", comment: "kind:description"
            )) {}
            EmptyStateView(
                String(localized: "No screenshots yet", comment: "kind:empty-state"),
                systemImage: AppWorkspaceSection.screenshots.systemImage,
                text: String(localized: """
                Each device \(viewModel.app.name) runs on needs at least one screenshot, and can have up to 10 in each language. \
                Click Add Screenshots to add your own, or Make Screenshots and Autopilot makes them from the app.
                """, comment: "kind:description")
            )
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.empty")
    }
}
