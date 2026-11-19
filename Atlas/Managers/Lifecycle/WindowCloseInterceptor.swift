//
//  WindowCloseInterceptor.swift
//  Atlas
//

import AppKit

/// Stands in as the main window's delegate so closing it (the close
/// button, ⌘W, Window → Close) can hide it instead: SwiftUI would tear the
/// window's views down on close, and with them the library, the MCP
/// server's workspace and the checks that keep running in the background.
/// Everything else goes to SwiftUI's own delegate, untouched.
@MainActor
final class WindowCloseInterceptor: NSObject, NSWindowDelegate {
    /// SwiftUI's delegate, which gets every other message.
    nonisolated(unsafe) weak var original: (any NSWindowDelegate)?
    /// Called on close: true lets the window close, false keeps it (the
    /// closure hides it itself).
    private let shouldClose: @MainActor (NSWindow) -> Bool

    init(original: (any NSWindowDelegate)?, shouldClose: @escaping @MainActor (NSWindow) -> Bool) {
        self.original = original
        self.shouldClose = shouldClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldClose(sender) else { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    override nonisolated func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original?.responds(to: aSelector) == true
    }

    override nonisolated func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
