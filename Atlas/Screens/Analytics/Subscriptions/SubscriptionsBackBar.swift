//
//  SubscriptionsBackBar.swift
//  Atlas
//

import SwiftUI

/// "‹ Subscriptions › Retention" over Retention, Offers and Billing and
/// Plans (README-DS §16, board 92): Subscriptions goes back to the summary,
/// and so does ⌘[. Two levels at most: the summary and one view.
struct SubscriptionsBackBar: View {
    let pane: SubscriptionsPane
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Button(action: onBack) {
                HStack(spacing: Spacing.tiny) {
                    Image(systemName: "chevron.left")
                        .accessibilityHidden(true)
                    Text(String(localized: "Subscriptions", comment: "kind:button · back to Analytics → Subscriptions"))
                }
            }
            .plainButton()
            .keyboardShortcut("[", modifiers: .command)
            .help(String(localized: "Back to Subscriptions  ⌘[", comment: "kind:tooltip"))
            .accessibilityLabel(Text(String(localized: "Back to Subscriptions", comment: "kind:accessibility-label")))
            .accessibilityIdentifier("analytics.subscriptions.back")
            Image(systemName: "chevron.right")
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text(pane.title)
                .atlasTextStyle(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .atlasTextStyle(.callout)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.subscriptions.breadcrumb")
    }
}

#Preview {
    SubscriptionsBackBar(pane: .retention) {}
        .padding()
}
