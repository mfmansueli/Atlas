//
//  FieldSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// A suggestion under its field, in the same form row so it scrolls and
/// reflows with it: the purple "Suggested" pill, who suggested it and why,
/// Now and Suggested on two rows, the limit after the change, and Dismiss,
/// Use and Edit, Accept. It never changes the field by itself. Landing
/// while the person looks it arrives (effect 2); accepted it settles
/// (effect 5): the tint goes, a check draws, and it closes.
struct FieldSuggestionCard: View {
    let fieldTitle: String
    let suggestion: FieldSuggestion
    /// What the field holds now, as shown; "" reads "Empty".
    let current: String
    /// The suggested value, as shown (a category by name).
    let suggested: String
    /// "75 / 100 bytes · frees 13", "28 / 30 characters"; nil for none.
    var meta: String?
    /// Picked values (categories, release) have nothing to edit.
    var canUseAndEdit = true
    let onDismiss: () -> Void
    let onUseAndEdit: () -> Void
    let onAccept: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            header
            values
            actions
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSettling ? Palette.raised : Palette.aiSurface, in: shape)
        .overlay(shape.strokeBorder(edge, lineWidth: isSettling ? 0.5 : 1))
        .modifier(SuggestionArrival(key: suggestion.id, arrivedAt: suggestion.arrivedAt, shape: shape))
        .id(suggestion.id)
        .modifier(AcceptSettle(isSettling: isSettling))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggestion for \(fieldTitle) from \(suggestion.source.title)"))
        .accessibilityIdentifier("suggestion.card")
    }

    private var edge: Color {
        isSettling ? Palette.separator : Palette.aiMark.opacity(contrast == .increased ? 0.8 : 0.35)
    }

    private func accept() {
        AcceptSettle.perform(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            Pill(text: String(localized: "Suggested"), style: .machineTranslated)
            SuggestionSourceTag(source: suggestion.source)
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("suggestion.reason")
        }
    }

    private var values: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
            GridRow {
                Text("NOW")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .frame(width: 74, alignment: .leading)
                Text(current.isEmpty ? String(localized: "Empty") : current)
                    .font(.subheadline)
                    .foregroundStyle(current.isEmpty ? Palette.label3 : Palette.label2)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GridRow {
                Text("SUGGESTED")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                    .frame(width: 74, alignment: .leading)
                SuggestedText(suggested, arrivalKey: suggestion.id, arrivedAt: suggestion.arrivedAt)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("suggestion.value")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(meta ?? "")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", action: onDismiss)
                .accessibilityIdentifier("suggestion.dismiss")
            if canUseAndEdit {
                Button("Use and Edit", action: onUseAndEdit)
                    .accessibilityIdentifier("suggestion.useAndEdit")
            }
            Button("Accept", action: accept)
                .rowActionButton()
                .accessibilityIdentifier("suggestion.accept")
        }
        .controlSize(.regular)
    }
}

#Preview {
    FieldSuggestionCard(
        fieldTitle: "Subtitle",
        suggestion: FieldSuggestion(
            id: "sg_1",
            appID: "1",
            target: SuggestionTarget(.storePage(locale: "en-US"), field: "subtitle"),
            value: "Private diary, mood & prompts",
            reason: "“Private” is the word people praise most in your last 220 reviews (41 times).",
            source: .assistant(client: "Claude Code")
        ),
        current: "Mood journal & prompts",
        suggested: "Private diary, mood & prompts",
        meta: "29 / 30 characters",
        onDismiss: {},
        onUseAndEdit: {},
        onAccept: {}
    )
    .padding()
    .frame(width: 620)
}
