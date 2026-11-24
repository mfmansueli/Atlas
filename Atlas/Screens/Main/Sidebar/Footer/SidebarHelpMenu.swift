//
//  SidebarHelpMenu.swift
//  Atlas
//

import SwiftUI

/// Help ▾ beside Settings at the bottom of the sidebar (README-DS §11,
/// board 71): Atlas Help (⌘?), Show the Tour and Keyboard Shortcuts, the
/// same items as macOS's Help menu.
struct SidebarHelpMenu: View {
    /// Show the Tour is there only while an app shows: the tips point at it.
    var showsTour = true
    let onHelp: () -> Void
    let onTour: () -> Void
    let onShortcuts: () -> Void

    var body: some View {
        Menu {
            Button(String(localized: "Atlas Help", comment: "kind:button"), systemImage: "questionmark.circle", action: onHelp)
                .keyboardShortcut("?", modifiers: .command)
            if showsTour {
                Button(String(localized: "Show the Tour", comment: "kind:section-title"), systemImage: "lightbulb", action: onTour)
            }
            Divider()
            Button(String(localized: "Keyboard Shortcuts", comment: "kind:menu-item"), systemImage: "keyboard", action: onShortcuts)
        } label: {
            SidebarFooterTile(title: String(localized: "Help", comment: "kind:button"), systemImage: "questionmark.circle", opensMenu: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(String(localized: "Atlas Help and the tour", comment: "kind:tooltip"))
        .accessibilityLabel(Text(String(localized: "Help", comment: "kind:button")))
    }
}

#Preview {
    SidebarHelpMenu(onHelp: {}, onTour: {}, onShortcuts: {})
        .frame(width: 110)
        .padding()
}
