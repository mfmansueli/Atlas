//
//  MenuBarSnapshot.swift
//  Atlas
//

import Foundation

/// Everything the menu bar's menu shows at one moment: what runs, what
/// needs the person, when Atlas last and next checks, and Review &
/// Push's count. `BackgroundWork` makes it; DEBUG scenes hand in canned
/// ones.
struct MenuBarSnapshot: Hashable, Sendable {
    var jobs: [BackgroundJob] = []
    var needs: [BackgroundNeed] = []
    /// "Last checked today at 18:20 · next check at 19:20".
    var checkLine: String
    var reviewPushCount = 0
    var isPaused = false
    /// The key was refused or Apple can't be reached: what went wrong.
    var connectionProblem: String?

    var state: MenuBarIconState {
        MenuBarIconState.resolve(
            isWorking: !jobs.isEmpty, isPaused: isPaused, hasConnectionProblem: connectionProblem != nil, needsCount: needs.count
        )
    }

    /// The line above the check times when nothing runs: "Nothing
    /// running" when something waits, else "Everything is up to date".
    var quietTitle: String {
        if let connectionProblem { return connectionProblem }
        if isPaused { return String(localized: "Background work is paused") }
        return needs.isEmpty ? String(localized: "Everything is up to date") : String(localized: "Nothing running")
    }
}
