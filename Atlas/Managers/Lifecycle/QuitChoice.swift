//
//  QuitChoice.swift
//  Atlas
//

import AppKit

/// Quit Atlas (⌘Q) while a push is running asks first: Quit After the
/// Push, Quit Now, or Cancel. A push stopped halfway is listed in Review &
/// Push next time.
enum QuitChoice: Hashable, Sendable {
    case afterPush
    case now
    case cancel

    /// The alert's answer, in its buttons' order.
    init(response: NSApplication.ModalResponse) {
        switch response {
        case .alertFirstButtonReturn: self = .afterPush
        case .alertSecondButtonReturn: self = .now
        default: self = .cancel
        }
    }

    @MainActor
    static func ask() -> QuitChoice {
        let alert = NSAlert()
        alert.messageText = String(localized: "A push is running")
        alert.informativeText = String(localized: """
        Atlas can quit once the push is done. If it quits now, what didn’t reach App Store Connect stays in Review & Push \
        for next time.
        """)
        alert.addButton(withTitle: String(localized: "Quit After the Push"))
        alert.addButton(withTitle: String(localized: "Quit Now"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        // From the menu bar, Atlas may have no window in front.
        NSApp.activate()
        return QuitChoice(response: alert.runModal())
    }
}
