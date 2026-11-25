//
//  TranslationSoundsBlock.swift
//  Atlas
//

import SwiftUI

/// Board 77's Sounds line under a suggestion in another language: the
/// fixed pill (Sounds native · Sounds translated · Sounds off), what it
/// means, and Use Natural Version (Undo once it's on), then up to two
/// notes, "phrase → what to write" and why. Always in the same place on the
/// card, like how sure. The notes stay left to right; their phrases are
/// isolated so a right-to-left phrase reads whole.
struct TranslationSoundsBlock: View {
    let translation: TranslationReading
    /// Who judged it, e.g. "Claude Code", for the tooltip.
    let client: String
    /// nil hides the button (a card that can't swap its text).
    var onUseNaturalVersion: (() -> Void)?
    var onUndoNaturalVersion: (() -> Void)?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            header
            if !translation.shownNotes.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    ForEach(Array(translation.shownNotes.enumerated()), id: \.offset) { _, note in
                        noteRow(note)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.top, Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.aiMark.opacity(contrast == .increased ? 0.8 : 0.35))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("How natural it sounds", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("suggestion.sounds")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            if let sounds = translation.sounds {
                Pill(text: sounds.word, style: sounds.pillStyle)
                    .fixedSize()
                    .help(TranslationReading.tooltip(judgedBy: client))
                    .accessibilityLabel(Text(sounds.word))
                    .accessibilityIdentifier("suggestion.sounds.pill")
            }
            if let summary = translation.summary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            if translation.offersNaturalVersion, let action = translation.usesNaturalVersion ? onUndoNaturalVersion : onUseNaturalVersion {
                Button(translation.usesNaturalVersion ? String(localized: "Undo", comment: "kind:button") : String(
                    localized: "Use Natural Version",
                    comment: "kind:button"
                ), action: action)
                    .plainButton()
                    .font(.subheadline)
                    .fixedSize()
                    .accessibilityIdentifier(translation.usesNaturalVersion ? "suggestion.natural.undo" : "suggestion.natural.use")
            }
        }
    }

    private func noteRow(_ note: TranslationNote) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(Self.noteLine(note))
            if !note.why.isEmpty {
                Text(note.why)
                    .foregroundStyle(Palette.label2)
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("suggestion.sounds.note")
    }

    /// "phrase → what to write", both in bold.
    static func noteLine(_ note: TranslationNote) -> AttributedString {
        var phrase = AttributedString(isolated(note.phrase))
        phrase.inlinePresentationIntent = .stronglyEmphasized
        var natural = AttributedString(isolated(note.natural))
        natural.inlinePresentationIntent = .stronglyEmphasized
        return phrase + AttributedString(" → ") + natural
    }

    /// First-strong isolate, so a right-to-left phrase in a left-to-right
    /// line keeps its own order (board 77, Hebrew).
    static func isolated(_ text: String) -> String {
        "\u{2068}\(text)\u{2069}"
    }
}

#Preview {
    TranslationSoundsBlock(
        translation: TranslationReading(
            sounds: .translated,
            notes: [TranslationNote(phrase: "über Jahre an Einträgen", natural: "in Einträgen aus vielen Jahren", why: "English word order.")],
            natural: "• Schnellere Suche in Einträgen aus vielen Jahren"
        ),
        client: "Claude Code",
        onUseNaturalVersion: {}
    )
    .padding()
    .frame(width: 520)
}
