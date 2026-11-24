//
//  NominationBuiltInCard.swift
//  Atlas
//

import SwiftUI

/// Atlas's own suggestion under an empty field, in purple: the type or
/// the description it would use, its one-line why, Dismiss and Accept (and
/// Use and Edit for the description).
struct NominationBuiltInCard: View {
    let suggestion: NominationBuiltInSuggestion
    let onDismiss: () -> Void
    let onAccept: (_ useAndEdit: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false
    @State private var arrivedAt = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: .builtIn)
                HowSureMeter(confidence: suggestion.confidence)
            }
            if suggestion.field == .description {
                Text(suggestion.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(NominationTextField.count(suggestion.text, isRequired: false))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            SuggestedText(suggestion.why, arrivalKey: arrivalKey, arrivedAt: arrivedAt)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("nominations.builtIn.why")
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("nominations.builtIn.dismiss")
                if suggestion.field == .description {
                    Button("Use and Edit") { onAccept(true) }
                        .accessibilityIdentifier("nominations.builtIn.useAndEdit")
                }
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("nominations.builtIn.accept")
            }
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .suggestionSurface(isSettling: isSettling, arrivalKey: arrivalKey, arrivedAt: arrivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.builtIn.\(suggestion.field.rawValue)")
    }

    private var title: String {
        switch suggestion.field {
        case .type: String(localized: "Suggested: \(suggestion.type?.title ?? "")", comment: "kind:suggestion-title")
        default: String(localized: "Suggested description", comment: "kind:suggestion-title")
        }
    }

    private var arrivalKey: String { "nomination.builtIn|\(suggestion.id)" }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept(false)
        }
    }
}
