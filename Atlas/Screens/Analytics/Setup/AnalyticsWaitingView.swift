//
//  AnalyticsWaitingView.swift
//  Atlas
//

import SwiftUI

/// Asked, waiting for Apple's first reports (board 74 · 7): the empty
/// state, with Check Now as its one action and when Atlas last looked
/// under it. No spinner; this takes a day or two, not minutes.
struct AnalyticsWaitingView: View {
    let appName: String
    let asked: Date
    /// When Atlas last looked for the reports; nil before the first look.
    var lastChecked: Date?
    var now: Date = .now
    let isChecking: Bool
    var errorMessage: String?
    let onCheck: () -> Void

    var body: some View {
        EmptyStateView(
            String(localized: "Waiting for Apple’s first reports", comment: "kind:empty-state"),
            systemImage: AppWorkspaceSection.analytics.systemImage,
            text: AnalyticsWaitingText.text(appName: appName, asked: asked, now: now),
            note: String(localized: "Apple counts only people who agree to share analytics with developers.", comment: "kind:description")
        ) {
            VStack(spacing: Spacing.small) {
                if let errorMessage { InlineMessage.error(errorMessage) }
                Button(String(localized: "Check Now", comment: "kind:button"), action: onCheck)
                    .secondaryButton()
                    .disabled(isChecking)
                    .accessibilityIdentifier("analytics.setup.checkNow")
                Text(checkedText)
                    .atlasTextStyle(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Palette.label3)
                    .accessibilityIdentifier("analytics.setup.waiting.checked")
            }
        }
        .accessibilityIdentifier("analytics.setup.waiting")
    }

    /// "Asked Apple today at 15:04 · Last checked today at 15:20: not there yet".
    private var checkedText: String {
        let askedText = String(localized: "Asked Apple \(AnalyticsText.moment(asked, now: now))")
        guard let lastChecked else { return askedText + " · " + String(localized: "Not checked yet") }
        return askedText + " · " + String(localized: "Last checked \(AnalyticsText.moment(lastChecked, now: now)): not there yet")
    }
}

#Preview {
    AnalyticsWaitingView(appName: "Lumen", asked: .now, isChecking: false, onCheck: {})
        .frame(width: 900, height: 560)
}
