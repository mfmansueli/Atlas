//
//  OverviewLastPush.swift
//  Atlas
//

import SwiftUI

/// "Last push" on the Overview: the newest push from Atlas with its
/// verdict; the card opens its result, All Changes the whole list.
struct OverviewLastPush: View {
    let summary: LastPushSummary
    let onOpen: () -> Void
    let onAll: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last push", comment: "kind:heading · Analytics Overview")
                    .atlasTextStyle(.title3)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.small)
                Button(String(localized: "All Changes", comment: "kind:button · Analytics Overview: opens After Changes"), action: onAll)
                    .plainButton()
                    .accessibilityIdentifier("analytics.overview.allChanges")
            }
            Button(action: onOpen) {
                HStack(spacing: Spacing.medium) {
                    VStack(alignment: .leading, spacing: Spacing.tiny) {
                        Text(summary.title)
                            .atlasTextStyle(.headline)
                            .lineLimit(2)
                        Text(summary.detail)
                            .atlasTextStyle(.callout)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Spacing.small)
                    Pill(text: summary.status, style: summary.verdict?.pillStyle ?? .neutral)
                }
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.raised, in: shape)
                .overlay {
                    shape.strokeBorder(contrast == .increased ? Palette.separator2 : Palette.separator, lineWidth: contrast == .increased ? 1 : 0.5)
                }
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(summary.accessibilityText))
            .accessibilityHint(Text("Opens its result", comment: "kind:accessibility-hint · Analytics Overview: Last push"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("analytics.overview.lastPush")
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}
