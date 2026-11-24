//
//  LanguageMenu.swift
//  Atlas
//

import SwiftUI

/// The language picker's menu (README-DS §12): Find a language at the top
/// with the total, focused when the menu opens; then languages with
/// suggestions first, each with its count (New page where the App Store has
/// no page yet), the ones up to date with a ✓, and, where some show the
/// primary language's content, those last ("Uses English (U.S.)
/// screenshots"). Typing filters at once and keeps the groups; closing the
/// menu clears it. A popover, because a menu can't show badges.
struct LanguageMenu: View {
    let model: LanguageBarModel
    let onSelect: (StoreLocale) -> Void
    /// Accept All Languages…, last; nil where the switch has none.
    var onAcceptAll: (() -> Void)?

    /// What Find a language has; it starts empty each time the menu opens.
    @State private var query = ""
    @FocusState private var findsLanguage: Bool

    var body: some View {
        let groups = model.menuGroups(matching: query)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                find
                if groups.isEmpty {
                    Text("No language matches “\(query.trimmingCharacters(in: .whitespaces))”.", comment: "kind:empty-state")
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.small)
                        .accessibilityIdentifier("languageBar.menu.none")
                }
                ForEach(groups) { group in
                    section(group)
                }
                if model.countsSuggestions, let onAcceptAll {
                    Divider()
                        .padding(.vertical, 5)
                        .padding(.horizontal, Spacing.xxSmall)
                    Button(action: onAcceptAll) {
                        Label(model.menuAcceptAllTitle, systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 28)
                            .padding(.horizontal, Spacing.small)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accentText)
                    .disabled(model.totalCount == 0)
                    .accessibilityIdentifier("languageBar.menu.acceptAll")
                }
            }
            .padding(Spacing.xSmall)
        }
        .frame(width: 330)
        .frame(maxHeight: 460)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("languageBar.menu")
        .defaultFocus($findsLanguage, true)
        .task { findsLanguage = true }
        .onDisappear { query = "" }
    }

    /// Find a language, with how many there are (board “sp-menu-find”).
    private var find: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return HStack(spacing: Spacing.xSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            TextField(String(localized: "Find a language", comment: "kind:placeholder"), text: $query)
                .textFieldStyle(.plain)
                .focused($findsLanguage)
                .onSubmit(selectOnlyMatch)
                .accessibilityIdentifier("languageBar.menu.find")
            Text(model.countText)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label3)
                .fixedSize()
        }
        .atlasTextStyle(.body)
        .padding(.horizontal, Spacing.small)
        .frame(height: Metrics.menuFieldHeight)
        .background(Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .padding(.horizontal, Spacing.tiny)
        .padding(.top, Spacing.tiny)
        .padding(.bottom, Spacing.xSmall)
    }

    /// Return on Find a language opens the one language it found.
    private func selectOnlyMatch() {
        let found = model.matchingEntries(query)
        guard found.count == 1, let only = found.first else { return }
        onSelect(only.locale)
    }

    @ViewBuilder
    private func section(_ group: LanguageMenuGroup) -> some View {
        if let title = group.title {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .padding(.horizontal, Spacing.small)
                .padding(.top, 7)
                .padding(.bottom, 3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("languageBar.menu.group.\(group.kind.rawValue)")
        }
        ForEach(group.entries) { entry in
            row(entry)
        }
    }

    private func row(_ entry: LanguageBarEntry) -> some View {
        Button {
            onSelect(entry.locale)
        } label: {
            HStack(spacing: Spacing.small) {
                FlagTile(regionCode: entry.locale.regionCode)
                    .frame(width: 20)
                Text(entry.locale.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if entry.comingCount > 0 {
                    Text("\(entry.comingCount) coming")
                        .font(.footnote)
                        .foregroundStyle(Palette.label2)
                        .fixedSize()
                }
                if entry.isNewPage {
                    Pill(text: String(localized: "New page"), style: .accent)
                        .fixedSize()
                }
                if let note = entry.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .fixedSize()
                }
                if model.countsSuggestions {
                    SuggestionBadge(count: entry.count)
                    if entry.count == 0, entry.note == nil {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.label3)
                    }
                }
            }
            .frame(minHeight: 28)
            .padding(.horizontal, Spacing.small)
            .background(
                entry.locale == model.current ? AnyShapeStyle(Palette.accentTint) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(entry.accessibilityText(countsSuggestions: model.countsSuggestions)))
        .accessibilityAddTraits(entry.locale == model.current ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("languageBar.menu.\(entry.locale.code)")
    }
}
