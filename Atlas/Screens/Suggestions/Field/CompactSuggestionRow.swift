//
//  CompactSuggestionRow.swift
//  Atlas
//

import SwiftUI

/// The suggestion under a question that's answered from a list: one line
/// with the suggested answer, who suggested it, Dismiss and Accept, and why
/// under it. Long texts use `FieldSuggestionCard`. It arrives and settles
/// like the card (effects 2 and 5).
struct CompactSuggestionRow: View {
    let suggested: String
    let suggestion: FieldSuggestion
    let onDismiss: () -> Void
    let onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text("Suggested: \(suggested)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                    .accessibilityIdentifier("suggestion.value")
                SuggestionSourceTag(source: suggestion.source)
                Spacer(minLength: Spacing.small)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("suggestion.dismiss")
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("suggestion.accept")
            }
            .controlSize(.regular)
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("suggestion.reason")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSettling ? Palette.fill1 : Palette.aiSurface, in: shape)
        .aiArrived(key: suggestion.id, arrivedAt: suggestion.arrivedAt)
        .id(suggestion.id)
        .aiDecided(isSettling: isSettling, checkAlignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestion.card")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
    }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }
}
