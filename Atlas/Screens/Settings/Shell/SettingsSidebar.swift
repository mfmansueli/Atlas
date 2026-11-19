//
//  SettingsSidebar.swift
//  Atlas
//

import SwiftUI

/// Settings' sidebar: a search field that keeps the panes with the words
/// typed, then the nine panes.
struct SettingsSidebar: View {
    @Binding var selection: SettingsPane
    @Binding var query: String

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, Spacing.small)
                .padding(.top, Spacing.small)
                .padding(.bottom, Spacing.xSmall)
            if panes.isEmpty {
                Text("No settings match “\(query)”.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("settings.search.none")
                Spacer()
            } else {
                // Buttons, not List(selection:): in the Settings scene the
                // list's own selection neither showed nor changed the pane.
                List {
                    ForEach(panes) { pane in
                        row(pane)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 200)
        .onChange(of: query) {
            // The pane shown stays one that matches.
            if !panes.contains(selection), let first = panes.first { selection = first }
        }
    }

    private func row(_ pane: SettingsPane) -> some View {
        let isSelected = selection == pane
        return Button {
            selection = pane
        } label: {
            Label(pane.title, systemImage: pane.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, Spacing.xSmall)
                .background(isSelected ? Palette.fill2 : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.nav.\(pane.rawValue)")
    }

    private var panes: [SettingsPane] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SettingsPane.allCases.filter { $0.matches(trimmed) }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("settings.search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.label3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 5)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}
