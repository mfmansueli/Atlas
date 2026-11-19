//
//  HelpCommands.swift
//  Atlas
//

import SwiftUI

/// The Help menu (board 49): Atlas Help (⌘?), Keyboard Shortcuts, two
/// articles people look for, Apple's system status, and writing to us.
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Atlas Help") { open(nil) }
                .keyboardShortcut("?", modifiers: .command)
            Button("Keyboard Shortcuts") { open("keys") }
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
}
