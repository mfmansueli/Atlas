//
//  QuitCommands.swift
//  Atlas
//

import SwiftUI

/// "Quit Atlas" (⌘Q) in the Atlas menu, the same as the menu bar's Quit: it
/// asks first while a push runs, and closes a sheet left open, which would
/// otherwise keep macOS from quitting without a word.
struct QuitCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appTermination) {
            Button("Quit Atlas") { AtlasLifecycle.shared.quit() }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
