//
//  AskFlightOverlay.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Draws the token's flight and the ring after it in a short-lived clear
/// window above the main one: the token rises into the toolbar, which the
/// content can't draw over, and the ring reaches past the button.
@MainActor
final class AskFlightOverlay {
    private var panel: NSPanel?
    private var removal: Task<Void, Never>?

    /// Flies from `source` to `target`, both frames on screen, in `window`.
    /// False when either isn't shown, so the toolbar works at once.
    func fly(from source: CGRect?, to target: CGRect?, in window: NSWindow?) -> Bool {
        guard let source, let target, let window, window.isVisible else { return false }
        let frame = window.frame
        // Top-left points inside the window, as SwiftUI draws.
        func local(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - frame.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let from = local(source)
        let to = local(target)
        let path = AskTokenPath(from: CGPoint(x: from.midX, y: from.midY), to: CGPoint(x: to.midX, y: to.midY))
        close()
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.setAccessibilityElement(false)
        panel.setAccessibilityHidden(true)
        panel.contentView = NSHostingView(rootView: AskFlightView(path: path, target: to, start: .now))
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel
        removal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AskTokenPath.landing + AskTokenPath.ringDuration + 0.05))
            guard !Task.isCancelled else { return }
            self?.close()
        }
        return true
    }

    private func close() {
        removal?.cancel()
        removal = nil
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.contentView = nil
        self.panel = nil
    }
}
