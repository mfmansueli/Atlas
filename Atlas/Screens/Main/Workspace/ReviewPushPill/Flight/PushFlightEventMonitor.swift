//
//  PushFlightEventMonitor.swift
//  Atlas
//

import AppKit

/// Tells a `PushFlightCenter` where the person clicks in the app's
/// windows (on screen, when the click ends: where a button acts), and when
/// they type. Clicks in menus and open panels aren't seen; nothing flies
/// from them.
@MainActor
final class PushFlightEventMonitor {
    private nonisolated(unsafe) var token: Any?

    init(center: PushFlightCenter) {
        token = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .keyDown]) { [weak center] event in
            let isClick = event.type == .leftMouseUp
            let point = NSEvent.mouseLocation
            MainActor.assumeIsolated {
                if isClick {
                    center?.noteClick(at: point)
                } else {
                    center?.noteTyping()
                }
            }
            return event
        }
    }

    deinit {
        if let token { NSEvent.removeMonitor(token) }
    }
}
