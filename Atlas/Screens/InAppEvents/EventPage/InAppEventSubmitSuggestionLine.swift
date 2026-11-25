//
//  InAppEventSubmitSuggestionLine.swift
//  Atlas
//

import SwiftUI

/// An assistant's suggestion to submit the event on its own, over the
/// page's footer: who suggests it, why, and Dismiss. Submitting stays the
/// header's Submit Event… with its confirmation.
struct InAppEventSubmitSuggestionLine: View {
    let suggestion: InAppEventSubmitSuggestion
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "sparkle")
                .imageScale(.small)
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(suggestion.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.submitSuggestion.why")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                .controlSize(.regular)
                .accessibilityIdentifier("events.submitSuggestion.dismiss")
        }
        .padding(Spacing.small)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .aiArrived(key: suggestion.id.uuidString, arrivedAt: suggestion.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("events.submitSuggestion")
    }

    /// "Claude Code suggests submitting it now, without a version."
    private var title: String {
        String(localized: "\(suggestion.client) suggests submitting it now, without a version. Use Submit Event… above.", comment: "kind:label")
    }
}
