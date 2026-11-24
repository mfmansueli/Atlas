//
//  MenuBarController.swift
//  Atlas
//

import AppKit
import Observation
import SwiftUI

/// The Atlas icon in the menu bar (board 46): an `NSStatusItem` whose
/// template image follows `BackgroundWork.iconState`, swapping the working
/// loop's eight frames about three times a second while something runs
/// (unless Reduce Motion is on or the setting is off), and opening
/// `MenuBarMenuView` in a panel underneath when clicked. It also shows the
/// "Atlas is still running" note there the first time the window closes.
@MainActor
final class MenuBarController {
    /// What the menu's lines do; the menu closes before each runs.
    var actions = MenuBarActions()

    private let work: BackgroundWork
    private let preferences: AppPreferences
    private let notifications = NotificationPreferences.shared
    private var statusItem: NSStatusItem?
    private var menuPanel: MenuBarPanel?
    private var notePanel: MenuBarPanel?
    private var frameTimer: Timer?
    private var refreshTimer: Timer?
    private var frame = 0
    private var drawn: Drawn?
    private var observers: [any NSObjectProtocol] = []

    private struct Drawn: Equatable {
        var state: MenuBarIconState
        var frame: Int?
    }

    init(work: BackgroundWork, preferences: AppPreferences) {
        self.work = work
        self.preferences = preferences
    }

    func start() {
        update()
        observe()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.update() }
        })
        // What depends on the clock alone (an Autopilot run going quiet).
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    // MARK: - The icon

    private func observe() {
        withObservationTracking {
            _ = work.iconState
            _ = preferences.showsMenuBarIcon
            _ = preferences.animatesMenuBarIcon
            _ = notifications.showsMenuBarDot
            _ = notifications.showsDockCount
            _ = work.needs.count
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.update()
                self?.observe()
            }
        }
    }

    private func update() {
        updateDockCount()
        guard preferences.showsMenuBarIcon else {
            removeStatusItem()
            return
        }
        let button = makeStatusItemIfNeeded()
        // Settings → Notifications → "Show a dot on the menu bar icon".
        let state = work.iconState == .needsYou && !notifications.showsMenuBarDot ? .idle : work.iconState
        let animates = state == .working && preferences.animatesMenuBarIcon
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animates { startFrames() } else { stopFrames() }
        draw(Drawn(state: state, frame: animates ? frame : nil), on: button)
    }

    /// Settings → Notifications → "Show the count on the Dock icon": what
    /// needs you, not what's suggested.
    private func updateDockCount() {
        let count = MenuBarController.dockCount(needs: work.needs, showsCount: notifications.showsDockCount)
        NSApp.dockTile.badgeLabel = count.map(String.init)
    }

    static func dockCount(needs: [BackgroundNeed], showsCount: Bool) -> Int? {
        guard showsCount else { return nil }
        let count = needs.count { $0.needsYou }
        return count > 0 ? count : nil
    }

    private func draw(_ drawn: Drawn, on button: NSStatusBarButton) {
        guard drawn != self.drawn else { return }
        self.drawn = drawn
        button.image = MenuBarGlyph.image(for: drawn.state, frame: drawn.frame)
        button.setAccessibilityLabel(drawn.state.accessibilityLabel)
    }

    private func startFrames() {
        guard frameTimer == nil else { return }
        frameTimer = Timer.scheduledTimer(withTimeInterval: MenuBarGlyph.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        guard let button = statusItem?.button else { return }
        frame = (frame + 1) % MenuBarGlyph.frameCount
        draw(Drawn(state: .working, frame: frame), on: button)
    }

    private func stopFrames() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    private func makeStatusItemIfNeeded() -> NSStatusBarButton {
        if let button = statusItem?.button { return button }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = .removalAllowed
        item.autosaveName = "Atlas"
        statusItem = item
        drawn = nil
        let button = item.button!
        button.target = self
        button.action = #selector(statusItemClicked)
        button.setAccessibilityIdentifier("menuBar.statusItem")
        button.setAccessibilityRole(.menuButton)
        return button
    }

    private func removeStatusItem() {
        stopFrames()
        menuPanel?.close()
        notePanel?.close()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
        drawn = nil
    }

    // MARK: - The menu

    @objc private func statusItemClicked() {
        toggleMenu()
    }

    func toggleMenu() {
        if let menuPanel, menuPanel.isVisible {
            menuPanel.close()
            return
        }
        // The click that took the panel's focus away already closed it.
        if let closedAt = menuPanel?.closedAt, Date.now.timeIntervalSince(closedAt) < 0.3 { return }
        notePanel?.close()
        let panel = MenuBarPanel(content: MenuBarLiveMenu(work: work, actions: closingActions), cornerRadius: Radius.card)
        menuPanel = panel
        panel.show(below: anchor)
    }

    /// `actions`, each closing the menu first.
    private var closingActions: MenuBarActions {
        let actions = actions
        let close: @MainActor () -> Void = { [weak self] in self?.menuPanel?.close() }
        return MenuBarActions(
            openAtlas: { close(); actions.openAtlas() },
            open: { close(); actions.open($0) },
            checkNow: { close(); actions.checkNow() },
            setPaused: { close(); actions.setPaused($0) },
            setAutoReplyPaused: { close(); actions.setAutoReplyPaused($0) },
            openSettings: { close(); actions.openSettings() },
            quit: { close(); actions.quit() }
        )
    }

    // MARK: - The note

    /// "Atlas is still running", under the icon, until a button closes it.
    func showStillRunningNote(onQuitWhenClosed: @escaping @MainActor () -> Void, onDismiss: @escaping @MainActor () -> Void) {
        guard statusItem != nil else { return }
        menuPanel?.close()
        notePanel?.close()
        let close: @MainActor () -> Void = { [weak self] in self?.notePanel?.close() }
        let note = StillRunningNote(
            onQuitWhenClosed: { close(); onQuitWhenClosed() },
            onDismiss: { close(); onDismiss() }
        )
        let panel = MenuBarPanel(content: note, cornerRadius: Radius.popover)
        panel.closesWhenInactive = false
        notePanel = panel
        panel.show(below: anchor)
    }

    /// The icon's frame on screen; the top right corner without one.
    private var anchor: NSRect {
        if let frame = statusItem?.button?.window?.frame { return frame }
        let screen = NSScreen.main?.frame ?? .zero
        return NSRect(x: screen.maxX - 240, y: screen.maxY - 24, width: 24, height: 24)
    }
}
