//
//  PushProgressSummary.swift
//  Atlas
//

import Foundation

/// The changes, screenshots and extras of a push counted as one: its title
/// ("Pushing 12 changes and 40 images", "50 pushed · 2 failed"), the
/// subtitle under it, the bar's progress and each reason something failed,
/// once, with the rows it stopped (`+Time` has the time line, `+Live`
/// reads the pushes).
struct PushProgressSummary: Hashable, Sendable {
    var entries: [PushProgressEntry]
    var isRunning: Bool
    /// Cancel Remaining was clicked: only the rows in flight still finish.
    var isCancelling = false
    /// When the pushes going now started.
    var startedAt: Date?
    /// While App Store Connect's hourly request limit is used up.
    var pausedUntil: Date?

    var totalCount: Int { entries.count }
    var finishedCount: Int { entries.count { $0.state.isFinished } }
    var doneCount: Int { entries.count { $0.state == .done } }
    var failedCount: Int { entries.count { $0.state.failureReason != nil } }
    var notSentCount: Int { entries.count { $0.state == .notSent } }
    var inFlightCount: Int { entries.count { $0.state == .sending } }
    /// What didn't go once nothing runs: not sent, and any row left waiting.
    var unsentCount: Int { totalCount - doneCount - failedCount }
    var progress: Double { entries.isEmpty ? 0 : Double(finishedCount) / Double(totalCount) }

    /// "12 changes, 40 images and 3 videos".
    var contentsTitle: String {
        let parts = PushProgressKind.allCases.compactMap { kind -> String? in
            let count = entries.count { $0.kind == kind }
            return count > 0 ? kind.countTitle(count) : nil
        }
        return parts.formatted(.list(type: .and))
    }

    /// "Pushing 12 changes and 40 images"; once it's over "All 52 pushed"
    /// (with what they were), or "50 pushed · 2 failed · 1 not sent".
    var title: String {
        guard !entries.isEmpty else { return isRunning ? String(localized: "Pushing…") : String(localized: "Nothing pushed") }
        if isRunning { return String(localized: "Pushing \(contentsTitle)") }
        if doneCount == totalCount {
            return totalCount == 1 ? String(localized: "\(contentsTitle) pushed") : String(localized: "All \(contentsTitle) pushed")
        }
        var parts = [String(localized: "\(doneCount) pushed")]
        if failedCount > 0 { parts.append(String(localized: "\(failedCount) failed")) }
        if unsentCount > 0 { parts.append(String(localized: "\(unsentCount) not sent")) }
        return parts.joined(separator: " · ")
    }

    /// "18 of 52 sent · 1 failed · 6 going now" while it runs (how many
    /// are in flight, Apple's processing included, whatever the push);
    /// once it's over, what happens to what didn't go.
    var subtitle: String {
        if isRunning {
            var parts = [String(localized: "\(finishedCount) of \(totalCount) sent")]
            if failedCount > 0 { parts.append(String(localized: "\(failedCount) failed")) }
            if inFlightCount > 0 { parts.append(String(localized: "\(inFlightCount) going now")) }
            return parts.joined(separator: " · ")
        }
        if failedCount > 0 { return String(localized: "Failed ones stay in Review & Push: retry them, or fix them first.") }
        if unsentCount > 0 { return String(localized: "\(unsentCount) not sent. They stay in Review & Push.") }
        return String(localized: "Everything reached App Store Connect.")
    }

    /// Each reason something failed, in the order they first happened,
    /// with the rows that failed for it.
    var failureGroups: [PushProgressFailureGroup] {
        var groups: [PushProgressFailureGroup] = []
        for entry in entries {
            guard let reason = entry.state.failureReason else { continue }
            if let index = groups.firstIndex(where: { $0.reason == reason }) {
                groups[index].titles.append(entry.title)
            } else {
                groups.append(PushProgressFailureGroup(reason: reason, titles: [entry.title]))
            }
        }
        return groups
    }
}
