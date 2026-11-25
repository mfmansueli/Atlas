//
//  PricingStrategySuggestionCard.swift
//  Atlas
//

import SwiftUI

/// A pricing strategy or mode an assistant suggested, at the top of
/// Pricing: what changes and why, each changed setting Now and New, and
/// Dismiss and Accept. It's Atlas's own setting: Accept changes it at once
/// (with Undo on the toast) and nothing goes to App Store Connect. It
/// arrives and settles like a field's suggestion (effects 2 and 5).
struct PricingStrategySuggestionCard: View {
    let suggestion: PricingStrategySuggestion
    let comparison: PricingStrategyComparison
    let onDismiss: () -> Void
    let onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    /// Rows shown before "and N more settings".
    private static let shownRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.xSmall) {
                Text(suggestion.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: Spacing.small)
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text("Suggested strategy", comment: "kind:label")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                    .lineLimit(1)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
                if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
            }
            Text(suggestion.why)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pricing.strategySuggestion.why")
            changes
            HStack(spacing: Spacing.small) {
                Text("Changes Atlas’s suggestions only. Nothing is pushed.", comment: "kind:label")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(String(localized: "Dismiss", comment: "kind:button")) {
                    AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss)
                }
                .accessibilityIdentifier("pricing.strategySuggestion.dismiss")
                Button(String(localized: "Accept", comment: "kind:button"), action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("pricing.strategySuggestion.accept")
            }
            .controlSize(.regular)
            if let details = suggestion.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSettling ? Palette.raised : Palette.aiSurface, in: shape)
        .aiArrived(key: suggestion.id, arrivedAt: suggestion.receivedAt)
        .aiDecided(isSettling: isSettling)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("pricing.strategySuggestion")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    /// Each changed setting: its name, Now and New.
    private var changes: some View {
        let rows = comparison.rows
        return Grid(alignment: .leading, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xxSmall) {
            GridRow {
                Color.clear.frame(width: 0, height: 0)
                Text("Now", comment: "kind:label")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                Text("New", comment: "kind:label")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ai)
            }
            ForEach(rows.prefix(Self.shownRows)) { row in
                GridRow {
                    Text(row.label)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                    Text(row.now)
                        .font(.callout)
                    Text(row.new)
                        .font(.callout.weight(.medium))
                }
                .lineLimit(1)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pricing.strategySuggestion.row.\(row.label)")
            }
            if rows.count > Self.shownRows {
                GridRow {
                    Text("and \(rows.count - Self.shownRows) more settings", comment: "kind:label")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .gridCellColumns(3)
                }
            }
        }
    }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }

    /// "Suggested strategy: Price Europe at 90%. 2 settings change."
    private var accessibilityText: String {
        String(
            localized: "Suggested strategy: \(suggestion.title). \(comparison.rows.count) settings change.",
            comment: "kind:label"
        )
    }
}
