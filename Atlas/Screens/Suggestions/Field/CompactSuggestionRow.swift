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
                    .foregroundStyle(Palette.machineTranslated)
                    .accessibilityHidden(true)
                Text("Suggested: \(suggested)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.machineTranslated)
                    .accessibilityIdentifier("suggestion.value")
                SuggestionSourceTag(source: suggestion.source)
                Spacer(minLength: Spacing.small)
                Button("Dismiss", action: onDismiss)
                    .accessibilityIdentifier("suggestion.dismiss")
                Button("Accept", action: accept)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("suggestion.accept")
            }
            .controlSize(.small)
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("suggestion.reason")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSettling ? Palette.fill1 : Palette.machineTranslatedTint, in: shape)
        .modifier(SuggestionArrival(key: suggestion.id, arrivedAt: suggestion.arrivedAt, shape: shape))
        .id(suggestion.id)
        .modifier(AcceptSettle(isSettling: isSettling, checkAlignment: .trailing))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestion.card")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    private func accept() {
        AcceptSettle.perform(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }
}
