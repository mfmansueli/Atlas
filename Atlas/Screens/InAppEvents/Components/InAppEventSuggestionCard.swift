//
//  InAppEventSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// The suggestion for the language being viewed: all three texts at once,
/// who suggested them and why, with Dismiss and Accept. Until it's
/// accepted, people there see the primary language, and the card says so.
struct InAppEventSuggestionCard: View {
    let languageName: String
    let suggestion: InAppEventTextSuggestion
    let fallbackNote: String?
    let onDismiss: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text("\(languageName): suggested for all three fields")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
            }
            if let fallbackNote {
                Text(fallbackNote)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if !suggestion.why.isEmpty {
                Text(suggestion.why)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("events.suggestion.why")
            }
            if let over = suggestion.overLimit {
                InlineMessage.warning(String(localized: "\(over.field.title) is \(over.count) characters; the limit is \(over.field.limit). Accept it and shorten it."))
                    .font(.subheadline)
            }
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                Button("Dismiss", action: onDismiss)
                    .accessibilityIdentifier("events.suggestion.dismiss")
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("events.suggestion.accept")
            }
            .controlSize(.small)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.machineTranslatedTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.machineTranslatedMark.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.suggestion")
    }
}
