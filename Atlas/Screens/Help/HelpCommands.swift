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
        CommandGroup(replacing: .help) {
            Button("Atlas Help") { open(nil) }
                .keyboardShortcut("?", modifiers: .command)
            Button(String(localized: "Show the Tour", comment: "kind:section-title")) { navigator?.requestsTour = true }
                .disabled(navigator == nil)
            Button("Keyboard Shortcuts") { open(Self.shortcutsArticleID) }
            Divider()
            Button("Connect App Store Connect") { open("connect") }
            Button("Fix a Problem") { open("fix") }
            Button("App Store Connect System Status") { HelpSupport.openSystemStatus() }
            Divider()
            Button("Contact Support…") { HelpSupport.contactSupport() }
            Button("Send Feedback…") { HelpSupport.sendFeedback() }
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
