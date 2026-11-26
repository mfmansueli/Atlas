//
//  AnalyticsTabEmptyView.swift
//  Atlas
//

import SwiftUI

/// An Analytics view with nothing to show yet (README-DS §14 and §16,
/// board 92): the small ContentUnavailableView with the view's symbol, the
/// case's title and Apple's rule behind it, 2 or 3 facts as key/value
/// lines, the one button that helps (Open Pricing, Open Version 1.4) and a
/// small line on what happens next. It scrolls, and ends above the
/// Autopilot bar.
struct AnalyticsTabEmptyView: View {
    let content: AnalyticsEmptyContent
    let systemImage: String
    /// "analytics.subscriptions.empty"; the button adds ".action".
    let identifier: String
    var onAction: (AnalyticsEmptyAction) -> Void = { _ in }

    var body: some View {
        ScrollView {
            EmptyStateView(content.title, systemImage: systemImage, text: content.text, size: .inline) {
                VStack(spacing: Spacing.large) {
                    if !content.facts.isEmpty {
                        AnalyticsEmptyFactsBox(facts: content.facts)
                    }
                    if let action = content.action {
                        Button(action.title) { onAction(action) }
                            .secondaryButton()
                            .accessibilityIdentifier("\(identifier).action")
                    }
                    if let note = content.note {
                        Text(note)
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: Metrics.emptyStateTextWidth)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityIdentifier(identifier)
        }
        .leavesChatRoom()
    }
}

#Preview {
    AnalyticsTabEmptyView(
        content: AnalyticsEmptyContent.subscriptions(SubscriptionsSoFar(today: AnalyticsDay(.now)), appName: "Lumen Journal")
            ?? AnalyticsEmptyContent(availability: .noCrashes, text: ""),
        systemImage: AnalyticsTab.subscriptions.systemImage,
        identifier: "preview"
    )
    .frame(width: 640, height: 480)
}
