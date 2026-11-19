//
//  PushController+Toolbar.swift
//  Atlas
//

import Foundation

// What the toolbar's Review & Push shows while a push runs with the sheet
// minimized: changes, screenshots and extras sent, of all of them.
extension PushController {
    /// Whether anything is being sent: changes, screenshots or extras.
    var isSendingAnything: Bool {
        isRunning || screenshots.isRunning || screenshots.extras.isPushing
    }

    /// Sent and total across what's running; nil when nothing is.
    var sendingProgress: (sent: Int, total: Int)? {
        guard isSendingAnything else { return nil }
        var sent = 0
        var total = 0
        if phase != .idle {
            sent += finishedCount
            total += totalCount
        }
        if let run = screenshots.run {
            sent += run.finishedCount
            total += run.totalCount
        }
        if let run = screenshots.extras.run {
            sent += run.finishedCount
            total += run.totalCount
        }
        return (sent, total)
    }
}
