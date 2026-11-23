//
//  InAppEventSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// The suggestion for the language being viewed: all three texts at once,
/// who suggested them and why, with Dismiss and Accept. Until it's
/// accepted, people there see the primary language, and the card says so.
/// It arrives and settles like any suggestion (effects 2 and 5).
struct InAppEventSuggestionCard: View {
    let languageName: String
    let suggestion: InAppEventTextSuggestion
    let fallbackNote: String?
    let onDismiss: () -> Void
    let onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text("\(languageName): suggested for all three fields")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
            }
            if let fallbackNote {
                Text(fallbackNote)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if !suggestion.why.isEmpty {
                SuggestedText(suggestion.why, arrivalKey: arrivalKey, arrivedAt: suggestion.date)
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
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("events.suggestion.accept")
            }
            .controlSize(.regular)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .suggestionSurface(isSettling: isSettling, arrivalKey: arrivalKey, arrivedAt: suggestion.date)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.suggestion")
    }

    private var arrivalKey: String { "\(suggestion.id)|\(suggestion.date.timeIntervalSinceReferenceDate)" }

    private func accept() {
        AcceptSettle.perform(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }
}
