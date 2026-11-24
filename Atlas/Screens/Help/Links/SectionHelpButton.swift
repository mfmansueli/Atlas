//
//  SectionHelpButton.swift
//  Atlas
//

import SwiftUI

/// The small ? beside a section's title: opens Atlas Help at that
/// section's article. A plain icon button (README-DS §4), drawn at 16 pt
/// with a 24 pt hit area.
struct SectionHelpButton: View {
    let section: AppWorkspaceSection
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            HelpNavigation.shared.open(section.helpArticleID)
            openWindow(id: HelpCommands.windowID)
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
                .foregroundStyle(Palette.label2)
                .frame(width: Spacing.xxLarge, height: Spacing.xxLarge)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(Text(String(localized: "Help for \(section.toolbarTitle)", comment: "kind:tooltip")))
        .accessibilityLabel(Text(String(localized: "Help for \(section.toolbarTitle)", comment: "kind:accessibility-label")))
        .accessibilityIdentifier("workspace.help")
    }
}
