//
//  LanguageBar.swift
//  Atlas
//

import SwiftUI

/// Over the Store Page's fields and the screenshots: the language in view
/// and how many suggestions it has, Accept All Languages beside it with the
/// total, arrows to the previous or next language with suggestions, how many
/// wait elsewhere, and Accept n in this language. When Accept All doesn't
/// ask first, the line under it says so and offers Ask First.
///
/// On the Store Page and Screenshots the language picker sits in the
/// window's toolbar beside the section's title (board 57: a control that
/// changes the whole page moves up), and Accept All Languages stays here,
/// next to the suggestions it accepts.
struct LanguageBar<Trailing: View>: View {
    let model: LanguageBarModel
    /// Accept All Languages is part of Pro and the person is on Free.
    var showsProChip = false
    /// The picker goes in the window's toolbar instead of the bar.
    var picksInToolbar = false
    let onSelect: (StoreLocale) -> Void
    let onAcceptAll: () -> Void
    let onAcceptHere: () -> Void
    let onAskFirst: () -> Void
    /// More controls at the end of the bar.
    @ViewBuilder var trailing: () -> Trailing

    @State private var showsMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            FlowLayout(spacing: Spacing.small) {
                if !picksInToolbar { picker }
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
            if model.acceptsRightAway, model.totalCount > 0 {
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
        .toolbar {
            if picksInToolbar {
                ToolbarItem(placement: .navigation) {
                    toolbarPicker
                }
            }
        }
    }

    /// The picker as a toolbar item: the flag, the language and its count.
    private var toolbarPicker: some View {
        Button {
            showsMenu.toggle()
        } label: {
            HStack(spacing: 6) {
                FlagTile(regionCode: model.current.regionCode)
                    .frame(width: 18)
                Text(model.current.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if model.hereCount > 0 {
                    Text(SuggestionBadge.text(for: model.hereCount))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Palette.ai, in: Capsule())
                }
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.xSmall)
            .contentShape(Rectangle())
        }
        .help(model.pickerAccessibilityText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.pickerAccessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("languageBar.picker")
        .toolbarItemFit([AnyHashable(model.current.name), AnyHashable(model.hereCount)])
        .reportsToolbarRoom(.languagePicker)
        .popover(isPresented: $showsMenu, arrowEdge: .bottom) { menu }
    }

    private var menu: some View {
        LanguageMenu(model: model) { locale in
            showsMenu = false
            onSelect(locale)
        } onAcceptAll: {
            showsMenu = false
            onAcceptAll()
        }
    }

    private var picker: some View {
        Button {
            showsMenu.toggle()
        } label: {
            HStack(spacing: 9) {
                FlagTile(regionCode: model.current.regionCode)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(model.current.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(model.hereText)
                        .font(.footnote)
                        .fontWeight(model.hereCount > 0 ? .semibold : .regular)
                        .foregroundStyle(model.hereCount > 0 ? Palette.ai : Palette.label2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
            }
            .padding(.leading, Spacing.small)
            .padding(.trailing, 10)
            .frame(width: 220, height: 40)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.pickerAccessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("languageBar.picker")
        .popover(isPresented: $showsMenu, arrowEdge: .bottom) { menu }
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
