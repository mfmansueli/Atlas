//
//  HelpCommands.swift
//  Atlas
//

import SwiftUI

/// The Help menu (board 49): Atlas Help (⌘?), Show the Tour and Keyboard
/// Shortcuts, as in the sidebar's Help ▾ (board 71), two articles people
/// look for, Apple's system status, and writing to us.
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceNavigator) private var navigator

    var body: some Commands {
        // macOS 26 menus: a symbol column for the items that have a
        // standard symbol (README-DS §13); System Status keeps the empty
        // slot.
        CommandGroup(replacing: .help) {
            Button("Atlas Help", systemImage: "questionmark.circle") { open(nil) }
                .keyboardShortcut("?", modifiers: .command)
            Button(String(localized: "Show the Tour", comment: "kind:section-title"), systemImage: "lightbulb") { navigator?.requestsTour = true }
                .disabled(navigator == nil)
            Button("Keyboard Shortcuts", systemImage: "keyboard") { open(Self.shortcutsArticleID) }
            Divider()
            Button("Connect to App Store Connect", systemImage: "key") { open("connect") }
            Button("Fix a Problem", systemImage: "wrench.and.screwdriver") { open("fix") }
            Button("App Store Connect System Status") { HelpSupport.openSystemStatus() }
            Divider()
            Button("Contact Support…", systemImage: "envelope") { HelpSupport.contactSupport() }
            Button("Send Feedback…", systemImage: "text.bubble") { HelpSupport.sendFeedback() }
        }
    }

    private func open(_ articleID: String?) {
        if let articleID { HelpNavigation.shared.open(articleID) } else { HelpNavigation.shared.goHome() }
        openWindow(id: HelpCommands.windowID)
    }

    static let windowID = "help"
    /// Help's Keyboard Shortcuts article.
    static let shortcutsArticleID = "keys"
}
