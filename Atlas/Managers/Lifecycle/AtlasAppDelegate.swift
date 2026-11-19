//
//  AtlasAppDelegate.swift
//  Atlas
//

import AppKit

/// AppKit's questions about launching, closing and quitting, answered by
/// `AtlasLifecycle`.
@MainActor
final class AtlasAppDelegate: NSObject, NSApplicationDelegate {
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_: Notification) {
        launchedAtLogin = Self.isLoginLaunch()
    }

    func applicationDidFinishLaunching(_: Notification) {
        AtlasLifecycle.shared.didFinishLaunching(atLogin: launchedAtLogin || Self.isLoginLaunch())
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AtlasLifecycle.shared.reopen(hasVisibleWindows: hasVisibleWindows)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        AtlasLifecycle.shared.terminatesAfterLastWindowClosed()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        AtlasLifecycle.shared.shouldTerminate()
    }

    /// Whether macOS opened Atlas as a login item ("Open Atlas at login"),
    /// from the launch's Apple event.
    private static func isLoginLaunch() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
