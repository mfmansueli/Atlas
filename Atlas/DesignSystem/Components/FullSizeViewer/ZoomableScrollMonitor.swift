//
//  ZoomableScrollMonitor.swift
//  Atlas
//

import AppKit

/// Two-finger scrolls in the app: `handler` takes the move and says
/// whether it used it (only while zoomed with the pointer over the
/// container), so a used scroll doesn't reach what's underneath.
@MainActor
final class ZoomableScrollMonitor {
    private var monitor: Any?

    func start(_ handler: @escaping (CGSize) -> Bool) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // A mouse wheel moves in lines, a trackpad in points.
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let delta = CGSize(width: event.scrollingDeltaX * scale, height: event.scrollingDeltaY * scale)
            return handler(delta) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    isolated deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
