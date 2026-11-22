//
//  AutoReplyArchive.swift
//  Atlas
//

import Foundation

/// One app's Reply Automatically on this Mac: the rule, each new review's
/// reply and the replies sent by themselves. Kept as JSON beside the
/// app's reviews, so the queue survives a quit and a sleep.
struct AutoReplyArchive: Codable, Hashable, Sendable {
    var rule = AutoReplyRule()
    var drafts: [AppReview.ID: AutoReplyDraft] = [:]
    var history: [AutoReplyHistoryEntry] = []
    /// The reviews Claude was asked to reply to, and when, so one isn't
    /// asked twice while it works.
    var requested: [AppReview.ID: Date] = [:]
    /// Why replies couldn't be written at the last check: “Claude Code
    /// isn't connected”; nil once they could.
    var writeProblem: String?

    /// How many went out by themselves on `date`'s day.
    func sentCount(on date: Date, calendar: Calendar = .current) -> Int {
        history.count { $0.undoneAt == nil && calendar.isDate($0.sentAt, inSameDayAs: date) }
    }

    var needsYouCount: Int { drafts.values.count { $0.state.needsYou } }

    /// The next reply to go out by itself.
    var nextSend: Date? { drafts.values.compactMap(\.state.sendAt).min() }
}
