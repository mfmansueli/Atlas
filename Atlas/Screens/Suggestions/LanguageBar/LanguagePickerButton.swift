//
//  LanguagePickerButton.swift
//  Atlas
//

import SwiftUI

/// The one language picker (README-DS §12): a pop-up button with the flag
/// and the language's full name ("English (U.S.)", never "U.K.") that opens
/// the language menu. It replaces language tabs everywhere: they don't scale
/// past a few languages.
struct LanguagePickerButton: View {
    let model: LanguageBarModel
    var style = LanguagePickerStyle.full
    var identifier = "languageBar.picker"
    let onSelect: (StoreLocale) -> Void
    /// The menu's Accept All Languages row; nil hides it.
    var onAcceptAll: (() -> Void)?

    @State private var showsMenu = false

    var body: some View {
        Button {
            showsMenu.toggle()
        } label: {
            switch style {
            case .full: fullLabel
            case .compact: compactLabel
            }
        }
        .buttonStyle(.plain)
        .help(model.pickerAccessibilityText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.pickerAccessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
        .popover(isPresented: $showsMenu, arrowEdge: .bottom) {
            LanguageMenu(
                model: model,
                onSelect: { locale in
                    showsMenu = false
                    onSelect(locale)
                },
                // Accept All Languages… closes the menu first.
                onAcceptAll: onAcceptAll.map { accept in
                    { () in
                        showsMenu = false
                        accept()
                    }
                }
            )
        }
    }

    /// Two lines: the name, and what's waiting here in purple.
    private var fullLabel: some View {
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
            chevron
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

    /// One line, as high as a menu: the name and its purple count.
    private var compactLabel: some View {
        HStack(spacing: Spacing.xSmall) {
            FlagTile(regionCode: model.current.regionCode)
                .frame(width: 18)
            Text(model.current.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if model.countsSuggestions {
                SuggestionBadge(count: model.hereCount, isSmall: true)
            }
            chevron
        }
        .padding(.horizontal, Spacing.small)
        .frame(height: Metrics.menuFieldHeight)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5)
        }
        .fixedSize()
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.label2)
            .accessibilityHidden(true)
    }
}
