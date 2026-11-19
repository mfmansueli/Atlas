//
//  MainWindowKeeper.swift
//  Atlas
//

import AppKit

/// Keeps the main window alive when the person closes it: with "Keep
/// running when the window is closed" on, closing hides it, so pushes,
/// Autopilot, the MCP server's workspace and the background checks go on,
/// and the Dock icon or Open Atlas brings it back where it was left. With
/// it off, closing quits Atlas once nothing is running. Also sets whether
/// Atlas shows in the Dock ("Only while a window is open").
@MainActor
final class MainWindowKeeper {
    private(set) weak var window: NSWindow?
    /// Whether the window is hidden by closing it (or at login).
    private(set) var isHidden = false
    /// Settings that decide what closing does; nil acts as a plain window.
    var preferences: AppPreferences?
    /// Whether something runs that should finish before quitting.
    var isBusy: @MainActor () -> Bool = { false }
    /// Called each time closing hid the window.
    var onHidden: @MainActor () -> Void = {}
    /// Opened at login: the window hides as soon as it's there.
    var hidesWhenAttached = false

    private var interceptor: WindowCloseInterceptor?
    private var quitting: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification, NSWindow.didMiniaturizeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // After the window has actually closed or shown.
                Task { @MainActor in self?.updateDockIcon() }
            })
        }
    }

    /// The main window, from `MainWindowAccessor`. Puts the close
    /// interceptor in place, again if SwiftUI replaced it.
    func attach(_ window: NSWindow) {
        if self.window !== window {
            self.window = window
            interceptor = nil
        }
        if window.delegate !== interceptor {
            let interceptor = WindowCloseInterceptor(original: window.delegate) { [weak self] window in
                self?.shouldClose(window) ?? true
            }
            self.interceptor = interceptor
            window.delegate = interceptor
        }
        if hidesWhenAttached {
            hidesWhenAttached = false
            hide()
        }
    }

    // MARK: - Showing and hiding

    /// Open Atlas, the Dock icon, a "Needs you" line: the window as it was.
    func show() {
        quitting?.cancel()
        quitting = nil
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        isHidden = false
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        window?.orderOut(nil)
        isHidden = true
        updateDockIcon()
    }

    /// Whether `show()` has a window to bring back.
    var canShow: Bool { window != nil }

    private func shouldClose(_: NSWindow) -> Bool {
        guard let preferences else { return true }
        if preferences.staysOpenWhenClosed {
            hide()
            onHidden()
            return false
        }
        guard isBusy() else { return true }
        // "Off: closing the window quits Atlas once nothing is running."
        hide()
        quitWhenIdle()
        return false
    }

    /// Quits as soon as the push or the run that's going has finished,
    /// unless the window comes back first.
    func quitWhenIdle() {
        guard quitting == nil else { return }
        quitting = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !isBusy() {
                    NSApp.terminate(nil)
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: - Dock

    /// Shows or hides the Dock icon: always, or only while the main window
    /// or Settings is open (a minimized window counts, so it can come back).
    func updateDockIcon() {
        guard let preferences else { return }
        let hasOpenWindow = NSApp.windows.contains(where: Self.countsAsOpen)
        // Without the menu bar icon, the Dock is the only way back in.
        let showsIcon = !preferences.showsMenuBarIcon || preferences.dockVisibility.showsIcon(hasOpenWindow: hasOpenWindow)
        let policy: NSApplication.ActivationPolicy = showsIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    /// A window the person opened: titled, at the normal level, not a
    /// panel (alerts, the menu bar's menu) and on screen or in the Dock.
    private static func countsAsOpen(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel), window.level == .normal, window.styleMask.contains(.titled) else { return false }
        return window.isVisible || window.isMiniaturized
    }
}
