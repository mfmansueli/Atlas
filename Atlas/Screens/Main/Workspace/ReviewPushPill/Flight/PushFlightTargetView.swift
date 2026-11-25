//
//  PushFlightTargetView.swift
//  Atlas
//

import AppKit
import SwiftUI

/// An empty AppKit view behind Review & Push: the chips' landing place
/// (`anchor`), and the width of its window, which folds the pill under
/// 700 pt.
struct PushFlightTargetView: NSViewRepresentable {
    let anchor: AskAnchor
    let onWindowWidth: @MainActor (CGFloat) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = WindowWidthView(onWindowWidth: onWindowWidth)
        view.setAccessibilityElement(false)
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context _: Context) {
        anchor.view = view
    }

    /// Reports its window's width when it moves into one and as it resizes.
    private final class WindowWidthView: NSView {
        let onWindowWidth: @MainActor (CGFloat) -> Void
        private var observer: NSObjectProtocol?

        init(onWindowWidth: @escaping @MainActor (CGFloat) -> Void) {
            self.onWindowWidth = onWindowWidth
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            onWindowWidth(window.frame.width)
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window else { return }
                    self.onWindowWidth(window.frame.width)
                }
            }
        }
    }
}
