//
//  ScreenshotsEmptyView.swift
//  Atlas
//

import SwiftUI

/// No screenshots yet (board 74 · 4). Screenshots has no create button at
/// the top, so Add Screenshots… is in the middle; the toolbar's Make
/// Screenshots… is the other way, named in the sentence.
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
                Add your own, or click Make Screenshots and Autopilot makes them from the app.
                """, comment: "kind:description")
            ) {
                Button(String(localized: "Add Screenshots…", comment: "kind:button")) { viewModel.addScreenshotsByHand() }
                    .primaryButton()
                    .accessibilityIdentifier("screenshots.empty.add")
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.empty")
    }
}
