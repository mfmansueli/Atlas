//
//  PageShotsProblemView.swift
//  Atlas
//

import SwiftUI

/// Why a page's set can't be made yet (the default page has no screenshots
/// made in Atlas, say), Close, and Open Screenshots when that's where it's
/// fixed.
struct PageShotsProblemView: View {
    let flow: PageShotsFlow
    let problem: String
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 30))
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text(problem)
                .font(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.shots.problem")
            HStack(spacing: Spacing.medium) {
                Button("Close") { flow.studio.presentedKey = nil }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pages.shots.close")
                // The default page's screenshots are missing: they're made
                // in Screenshots.
                if flow.source != nil, let navigator {
                    Button("Open Screenshots") {
                        flow.studio.presentedKey = nil
                        navigator.open(.screenshots)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pages.shots.openScreenshots")
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xLarge)
    }
}
