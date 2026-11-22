//
//  MenuBarActions.swift
//  Atlas
//

import Foundation

/// What the menu bar's menu does when a line is clicked. The menu closes
/// first; `MenuBarController` wires these to the app, DEBUG scenes to
/// nothing.
struct MenuBarActions {
    var openAtlas: @MainActor () -> Void = {}
    var open: @MainActor (BackgroundDestination) -> Void = { _ in }
    var checkNow: @MainActor () -> Void = {}
    var setPaused: @MainActor (Bool) -> Void = { _ in }
    /// Pause Auto-Reply for every app that has it on (board 58).
    var setAutoReplyPaused: @MainActor (Bool) -> Void = { _ in }
    var openSettings: @MainActor () -> Void = {}
    var quit: @MainActor () -> Void = {}
}
