//
//  PushFlightPanel.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Draws a `PushFlightCenter`'s chips in a clear window over the one
/// Review & Push is in, while any are in the air: they start wherever the
/// person clicked, a sheet's Accept too, and land at the bottom. Clicks
/// go through it.
@MainActor
final class PushFlightPanel: PushFlightPresenting {
    private var panel: NSPanel?

    func present(_ center: PushFlightCenter) {
        guard panel == nil, let window = center.targetWindow, window.isVisible else { return }
        let frame = window.frame
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
        panel.contentView = NSHostingView(rootView: Layer(center: center, frame: frame))
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel
    }

    func dismiss() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.contentView = nil
        self.panel = nil
    }

    /// The center's chips, from screen points to the panel's.
    private struct Layer: View {
        let center: PushFlightCenter
        let frame: CGRect

        var body: some View {
            PushFlightLayer(flights: center.flights) { point in
                CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
            }
        }
    }
}
