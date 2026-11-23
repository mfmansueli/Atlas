//
//  FirstSyncProgress+Done.swift
//  Atlas
//

import Foundation

// The first sync's last step (the canvas's Welcome `checking-done`): every
// app read, then Open Atlas.
extension FirstSyncProgress {
    /// "Your 6 apps are ready".
    var doneTitle: String {
        switch appCount ?? syncedCount {
        case 0: String(localized: "Atlas is ready", comment: "kind:done-state")
        case 1: String(localized: "Your app is ready", comment: "kind:done-state")
        case let count: String(localized: "Your \(count) apps are ready", comment: "kind:done-state")
        }
    }

    /// "Read every store page, screenshot and price in Northpier Studio.
    /// Nothing changed in App Store Connect."
    var doneSummary: String {
        let read = if let teamName {
            String(localized: "Read every store page, screenshot and price in \(teamName).", comment: "kind:done-state")
        } else {
            String(localized: "Read every store page, screenshot and price.", comment: "kind:done-state")
        }
        return read + " " + String(localized: "Nothing changed in App Store Connect.", comment: "kind:done-state")
    }

    /// "6 of 6 · read just now".
    var doneDetail: String {
        let count = appCount ?? syncedCount
        return String(localized: "\(count) of \(count) · read just now", comment: "kind:done-state")
    }
}
