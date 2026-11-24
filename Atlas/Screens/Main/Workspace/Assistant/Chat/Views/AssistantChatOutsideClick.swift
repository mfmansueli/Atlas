//
//  AssistantChatOutsideClick.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Closes the open chat on a click in the window outside it (board 69: a
/// click on the content closes it), unless `keepsOpen`: while the person
/// writes, the panel stays.
struct AssistantChatOutsideClick: ViewModifier {
    let isActive: Bool
    let keepsOpen: Bool
    let onClose: () -> Void

    /// What the event monitor reads when a click comes: the panel's frame
    /// and whether it stays, as they are then.
    @MainActor
    private final class Watch {
        var frame: CGRect = .zero
        var keepsOpen = false
        var onClose: () -> Void = {}
        var monitor: Any?
    }

    @State private var watch = Watch()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { watch.frame = $0 })
            .onChange(of: keepsOpen, initial: true) { _, keeps in watch.keepsOpen = keeps }
            .onChange(of: isActive, initial: true) { _, active in
                watch.onClose = onClose
                if active { install() } else { remove() }
            }
            .onDisappear(perform: remove)
    }

    private func install() {
        guard watch.monitor == nil else { return }
        let watch = watch
        watch.monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            MainActor.assumeIsolated {
                if !watch.keepsOpen, let window = event.window,
                   Self.isOutside(event.locationInWindow, frame: watch.frame, windowHeight: window.contentView?.frame.height)
                {
                    watch.onClose()
                }
            }
            return event
        }
    }

    private func remove() {
        if let monitor = watch.monitor { NSEvent.removeMonitor(monitor) }
        watch.monitor = nil
    }

    /// Whether a click at `location` (AppKit's, from the bottom) lands
    /// outside `frame` (SwiftUI's, from the top of the window's content).
    nonisolated static func isOutside(_ location: CGPoint, frame: CGRect, windowHeight: CGFloat?) -> Bool {
        guard let windowHeight, !frame.isEmpty else { return false }
        let point = CGPoint(x: location.x, y: windowHeight - location.y)
        return !frame.contains(point)
    }
}

extension View {
    /// Closes the chat on a click outside it; see `AssistantChatOutsideClick`.
    func closesOnOutsideClick(_ isActive: Bool, keepsOpen: Bool, onClose: @escaping () -> Void) -> some View {
        modifier(AssistantChatOutsideClick(isActive: isActive, keepsOpen: keepsOpen, onClose: onClose))
    }
}
