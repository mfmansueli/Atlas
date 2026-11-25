//
//  GracePeriodSuggestionLine.swift
//  Atlas
//

import SwiftUI

/// An assistant's suggestion to turn on Billing Grace Period, at the top of
/// Billing and Plans: who suggests how long, why, Dismiss and Turn On…,
/// which opens the confirmation with that length.
struct GracePeriodSuggestionLine: View {
    let suggestion: GracePeriodSuggestion
    let onDismiss: () -> Void
    let onTurnOn: () -> Void

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
                    .accessibilityIdentifier("analytics.billing.suggestion.why")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                .accessibilityIdentifier("analytics.billing.suggestion.dismiss")
            Button(String(localized: "Turn On…", comment: "kind:button"), action: onTurnOn)
                .rowActionButton()
                .accessibilityIdentifier("analytics.billing.suggestion.turnOn")
        }
        .controlSize(.regular)
        .padding(Spacing.small)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .aiArrived(key: suggestion.id.uuidString, arrivedAt: suggestion.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("analytics.billing.suggestion")
    }

    /// "Claude Code suggests turning on Billing Grace Period for 16 days."
    private var title: String {
        String(
            localized: "\(suggestion.client) suggests turning on Billing Grace Period for \(suggestion.duration.title).",
            comment: "kind:label"
        )
    }
}
