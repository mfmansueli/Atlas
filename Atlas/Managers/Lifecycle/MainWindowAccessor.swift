//
//  MainWindowAccessor.swift
//  Atlas
//

import AppKit
import SwiftUI

/// An empty view that hands the window it's in to `onWindow`, once it's
/// in one and again whenever it moves to another: how the main window
/// reaches `MainWindowKeeper`.
struct MainWindowAccessor: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow) -> Void

    func makeNSView(context _: Context) -> NSView {
        WindowReportingView(onWindow: onWindow)
    }

    func updateNSView(_ view: NSView, context _: Context) {
        if let window = view.window { onWindow(window) }
    }

    private final class WindowReportingView: NSView {
        let onWindow: @MainActor (NSWindow) -> Void

        init(onWindow: @escaping @MainActor (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}
