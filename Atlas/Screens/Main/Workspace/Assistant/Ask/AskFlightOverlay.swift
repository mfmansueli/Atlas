//
//  AskFlightOverlay.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Draws the spark's trail (effect 1, `TrailView`) in a short-lived clear
/// window above the main one: the spark rises into the toolbar, which the
/// content can't draw over, then comes down to the place of the work.
@MainActor
final class AskFlightOverlay {
    private var panel: NSPanel?
    private var removal: Task<Void, Never>?

    /// Flies from `source` to `target` (the Autopilot button) and on to
    /// `place` (the source itself when nil), all frames on screen, in
    /// `window`. False when the source or the target isn't shown, so the
    /// toolbar works at once.
    func fly(from source: CGRect?, to target: CGRect?, place: CGRect? = nil, in window: NSWindow?) -> Bool {
        guard let source, let target, let window, window.isVisible else { return false }
        let frame = window.frame
        // Top-left points inside the window, as SwiftUI draws.
        func local(_ rect: CGRect) -> CGPoint {
            CGPoint(x: rect.midX - frame.minX, y: frame.maxY - rect.midY)
        }
        let path = TrailPath(from: local(source), via: local(target), to: local(place ?? source))
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
        panel.contentView = NSHostingView(rootView: TrailView(path: path, start: .now))
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel
        removal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(TrailPath.delay + path.duration + 0.05))
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
