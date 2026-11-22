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
    /// Answers the notifications' buttons (board 58).
    private let notificationResponder = AtlasNotificationResponder()

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
            setAutoReplyPaused: { [weak work] paused in
                guard let work else { return }
                work.autoReply.setPaused(paused, forAll: work.library.map(\.id))
            },
            openSettings: { [weak self] in self?.showSettings() },
            quit: { [weak self] in self?.quit() }
        )
        self.menuBar = menuBar
    }

    // MARK: - AppKit's questions

    func didFinishLaunching(atLogin: Bool) {
        preferences?.appearance.apply()
        guard isActive else { return }
        menuBar?.start()
        work?.start()
        notificationResponder.open = { [weak self] in self?.open($0) }
        notificationResponder.sendReply = { appID, reviewID in
            await AutoReplyCenter.shared.sendFromNotification?(appID, reviewID) ?? false
        }
        AtlasNotifier.shared.register(notificationResponder)
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

    /// Quit Atlas, from the menu bar's menu or ⌘Q. A sheet left open on the
    /// window (Review & Push, say) keeps macOS from quitting without a word,
    /// so it's closed first: after asking, when a push runs.
    func quit() {
        if isActive, let push, isPushing(push) {
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

    /// A SwiftUI sheet that AppKit's `endSheet` closes comes back (its
    /// state still says it's shown) and AppKit then ignores the quit: each
    /// is cancelled like Esc, which SwiftUI dismisses for good, and Atlas
    /// quits once they're gone.
    private func terminateClosingSheets(attempt: Int = 0) {
        let sheets = NSApp.windows.compactMap(\.attachedSheet)
        guard !sheets.isEmpty, attempt < Self.sheetCloseAttempts else { return terminate() }
        for sheet in sheets {
            sheet.cancelOperation(nil)
            if let parent = sheet.sheetParent, parent.attachedSheet == sheet { parent.endSheet(sheet) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sheetCloseTime) { [weak self] in
            self?.terminateClosingSheets(attempt: attempt + 1)
        }
    }

    /// A sheet's closing animation, and how many sheets over sheets.
    private static let sheetCloseTime: TimeInterval = 0.3
    private static let sheetCloseAttempts = 4

    private func terminate() {
        quitIsConfirmed = true
        NSApp.terminate(nil)
        // Something else said no: ask again next time.
        quitIsConfirmed = false
    }

    private static func waitForPushes(_ push: PushController) async {
        await push.waitUntilFinished()
        while push.isSendingAnything {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Changes, screenshots or extras going out.
    private func isPushing(_ push: PushController) -> Bool {
        push.isSendingAnything
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
