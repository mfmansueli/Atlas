//
//  SheetParentSizeReader.swift
//  Atlas
//

import AppKit
import SwiftUI

/// An empty view, put behind a sheet's content, that reports the content
/// size of the window the sheet is attached to: once the sheet is up, and
/// again whenever that window is resized, so the sheet can stay inside it.
struct SheetParentSizeReader: NSViewRepresentable {
    let onChange: @MainActor (CGSize) -> Void

    func makeNSView(context _: Context) -> NSView {
        ParentReportingView(onChange: onChange)
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class ParentReportingView: NSView {
        let onChange: @MainActor (CGSize) -> Void
        private weak var parent: NSWindow?
        private var observers: [NSObjectProtocol] = []

        init(onChange: @escaping @MainActor (CGSize) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            attach()
            // The sheet's window gets its parent once it's presented.
            let shown = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.attach() }
            }
            observers.append(shown)
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        private func attach() {
            guard let sheetParent = window?.sheetParent, sheetParent !== parent else { return }
            parent = sheetParent
            let resized = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: sheetParent, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            observers.append(resized)
            report()
        }

        private func report() {
            guard let parent else { return }
            onChange(parent.contentLayoutRect.size)
        }

        private func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            parent = nil
        }
    }
}
