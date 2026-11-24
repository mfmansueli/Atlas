//
//  LanguageBar.swift
//  Atlas
//

import SwiftUI

/// Over the Store Page's fields, the screenshots, an event's texts and a
/// product page (README-DS §12, one picker, not tabs): the language picker
/// with how many suggestions wait here, Accept All Languages beside it with
/// the total, ‹ › to the previous or next language with suggestions (⌘[ and
/// ⌘]), how many wait elsewhere, and Accept n in this language. When Accept
/// All doesn't ask first, the line under it says so and offers Ask First.
/// The picker changes the editor and the preview together.
struct LanguageBar<Trailing: View>: View {
    let model: LanguageBarModel
    /// Accept All Languages is part of Pro and the person is on Free.
    var showsProChip = false
    let onSelect: (StoreLocale) -> Void
    let onAcceptAll: () -> Void
    let onAcceptHere: () -> Void
    var onAskFirst: () -> Void = {}
    /// More controls at the end of the bar.
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            FlowLayout(spacing: Spacing.small) {
                LanguagePickerButton(model: model, style: .full, onSelect: onSelect, onAcceptAll: onAcceptAll)
                acceptAll
                arrows
                if !model.restText.isEmpty {
                    Text(model.restText)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .accessibilityIdentifier("languageBar.rest")
                }
                if model.hereCount > 0 {
                    Button(model.acceptHereTitle, action: onAcceptHere)
                        .accessibilityIdentifier("languageBar.acceptHere")
                }
                trailing()
            }
            if model.showsAcceptsRightAway {
                acceptsRightAwayLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.xSmall)
        .padding(.trailing, 10)
        .padding(.vertical, Spacing.xSmall)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("languageBar")
    }

    /// Prominent while there's something to accept; once every language is
    /// reviewed it's a plain ✓ that says so, not a blue button that does
    /// nothing.
    @ViewBuilder
    private var acceptAll: some View {
        if model.totalCount > 0 {
            acceptAllButton.buttonStyle(.borderedProminent)
        } else {
            acceptAllButton.buttonStyle(.bordered)
        }
    }

    private var acceptAllButton: some View {
        Button(action: onAcceptAll) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: model.totalCount > 0 ? "sparkles" : "checkmark")
                    .imageScale(.small)
                Text(model.acceptAllTitle)
                SuggestionBadge(count: model.totalCount)
                if showsProChip { ProChip() }
            }
        }
        .disabled(model.totalCount == 0)
        .accessibilityLabel(Text(model.acceptAllAccessibilityText))
        .accessibilityIdentifier("languageBar.acceptAll")
    }

    private var arrows: some View {
        ControlGroup {
            Button {
                if let previous = model.previous { onSelect(previous) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(model.previous == nil || model.previous == model.current)
            .keyboardShortcut("[", modifiers: .command)
            .help(arrowHelp(model.previous, String(localized: "Previous language with suggestions"), shortcut: "⌘["))
            .accessibilityLabel(Text(arrowHelp(model.previous, String(localized: "Previous language with suggestions"))))
            .accessibilityIdentifier("languageBar.previous")
            Button {
                if let next = model.next { onSelect(next) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(model.next == nil || model.next == model.current)
            .keyboardShortcut("]", modifiers: .command)
            .help(arrowHelp(model.next, String(localized: "Next language with suggestions"), shortcut: "⌘]"))
            .accessibilityLabel(Text(arrowHelp(model.next, String(localized: "Next language with suggestions"))))
            .accessibilityIdentifier("languageBar.next")
        }
        .fixedSize()
    }

    /// "Next language with suggestions: German  ⌘]"; VoiceOver reads it
    /// without the shortcut.
    private func arrowHelp(_ locale: StoreLocale?, _ title: String, shortcut: String? = nil) -> String {
        let help = locale.map { "\(title): \($0.name)" } ?? title
        return shortcut.map { "\(help)  \($0)" } ?? help
    }

    private var acceptsRightAwayLine: some View {
        HStack(spacing: Spacing.small) {
            Pill(text: String(localized: "Accepts right away"), style: .accent)
                .fixedSize()
            Text("Accept All Languages doesn’t show the suggestions first. You can undo each time.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
            Button("Ask First", action: onAskFirst)
                .buttonStyle(.link)
                .font(.subheadline)
                .accessibilityIdentifier("languageBar.askFirst")
        }
        .padding(.leading, Spacing.xxSmall)
    }
}
