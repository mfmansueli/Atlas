//
//  DesignSystemCatalogCommands.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// DEBUG only: the Debug menu, with Design System Catalog… (⌥⌘D), Rule
/// zero's window of the design system drawn by itself.
struct DesignSystemCatalogCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Design System Catalog…") { openWindow(id: Self.windowID) }
                .keyboardShortcut("d", modifiers: [.command, .option])
        }
    }

    static let windowID = "designSystemCatalog"
}
#endif
