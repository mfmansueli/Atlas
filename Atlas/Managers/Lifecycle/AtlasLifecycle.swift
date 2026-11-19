//
//  AtlasLifecycle.swift
//  Atlas
//

import AppKit

/// Atlas as a Mac app that keeps running (boards 45–46): the menu bar
/// icon, the main window that hides instead of closing, the checks it
/// makes on its own, opening at login without a window, and asking before
/// quitting in the middle of a push. `AtlasAppDelegate` hands it AppKit's
/// questions; `AtlasApp` configures it.
///
/// DEBUG scenes and the unit tests' host leave it inactive: a plain
/// window, no icon, no background checks, quitting without asking.
@MainActor
final class AtlasLifecycle {
    static let shared = AtlasLifecycle()

    let windows = MainWindowKeeper()
    private(set) var menuBar: MenuBarController?
    private(set) var work: BackgroundWork?
    private(set) var isActive = false
    /// Opens the main window when SwiftUI really closed it (there's no
    /// hidden one to show); set from inside the window's scene.
    var openMainWindow: (@MainActor () -> Void)?
    /// Opens Settings; set from inside a scene, where SwiftUI offers it.
    var openSettings: (@MainActor () -> Void)?

    private var preferences: AppPreferences?
    private var push: PushController?
    /// The menu bar's Quit already asked about the push.
    private var quitIsConfirmed = false

    func configure(work: BackgroundWork, preferences: AppPreferences, push: PushController, isActive: Bool) {
        self.work = work
        self.preferences = preferences
        self.push = push
        self.isActive = isActive
        guard isActive else { return }
        windows.preferences = preferences
        windows.isBusy = { [weak work] in work?.isBusy ?? false }
        windows.onHidden = { [weak self] in self?.windowWasHidden() }
        let menuBar = MenuBarController(work: work, preferences: preferences)
        menuBar.actions = MenuBarActions(
            openAtlas: { [weak self] in self?.showMainWindow() },
            open: { [weak self] in self?.open($0) },
            checkNow: { [weak work] in Task { await work?.check() } },
            setPaused: { [weak work] in work?.setPaused($0) },
            openSettings: { [weak self] in self?.showSettings() },
            quit: { [weak self] in self?.quitFromMenuBar() }
        )
        self.menuBar = menuBar
    }

    // MARK: - AppKit's questions

    func didFinishLaunching(atLogin: Bool) {
        preferences?.appearance.apply()
        guard isActive else { return }
        menuBar?.start()
        work?.start()
        // "Starts in the menu bar, with no window" (only with the icon
        // there to open it).
        if atLogin, preferences?.showsMenuBarIcon == true {
            if windows.canShow { windows.hide() } else { windows.hidesWhenAttached = true }
        }
        windows.updateDockIcon()
    }

    /// The Dock icon was clicked: the hidden window comes back.
    func reopen(hasVisibleWindows: Bool) -> Bool {
        guard isActive, windows.isHidden || !hasVisibleWindows, windows.canShow else { return true }
        windows.show()
        return false
    }

    func terminatesAfterLastWindowClosed() -> Bool {
        guard isActive, let preferences else { return true }
        return !preferences.staysOpenWhenClosed && work?.isBusy != true
    }

    /// Quit Atlas while a push runs: after it, now (what's left stays in
    /// Review & Push), or not.
    func shouldTerminate() -> NSApplication.TerminateReply {
        guard isActive, !quitIsConfirmed, let push, isPushing(push) else { return .terminateNow }
        switch QuitChoice.ask() {
        case .now:
            return .terminateNow
        case .cancel:
            return .terminateCancel
        case .afterPush:
            Task {
                await Self.waitForPushes(push)
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    /// Quit Atlas in the menu bar's menu. A sheet left open on the window
    /// (Review & Push, say) keeps macOS from quitting, and with the window
    /// hidden nobody would see why, so it's closed first: after asking,
    /// when a push runs.
    func quitFromMenuBar() {
        if let push, isPushing(push) {
            switch QuitChoice.ask() {
            case .cancel:
                return
            case .now:
                break
            case .afterPush:
                Task {
                    await Self.waitForPushes(push)
                    terminateClosingSheets()
                }
                return
            }
        }
        terminateClosingSheets()
    }

    private func terminateClosingSheets() {
        quitIsConfirmed = true
        for window in NSApp.windows {
            if let sheet = window.attachedSheet { window.endSheet(sheet) }
        }
        NSApp.terminate(nil)
        // Something else said no: ask again next time.
        quitIsConfirmed = false
    }

    private static func waitForPushes(_ push: PushController) async {
        await push.waitUntilFinished()
        while push.screenshots.run?.isRunning == true {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func isPushing(_ push: PushController) -> Bool {
        push.isRunning || push.screenshots.run?.isRunning == true
    }

    // MARK: - Opening

    func showMainWindow() {
        if windows.canShow {
            windows.show()
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            openMainWindow?()
        }
    }

    /// A "Needs you" line or Review & Push…: the window, at that place.
    func open(_ destination: BackgroundDestination) {
        showMainWindow()
        work?.open(destination)
    }

    func showSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        openSettings?()
    }

    /// The first time closing hides the window, the note under the icon
    /// says Atlas is still running.
    private func windowWasHidden() {
        guard let preferences, !preferences.hasSeenStillRunningNote else { return }
        preferences.hasSeenStillRunningNote = true
        menuBar?.showStillRunningNote(
            onQuitWhenClosed: { [weak self] in
                preferences.keepsRunning = false
                self?.windows.quitWhenIdle()
            },
            onDismiss: {}
        )
    }
}
