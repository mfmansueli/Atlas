//
//  PushProgressSummary+Time.swift
//  Atlas
//

import Foundation

/// The time line under the bar: "6:12 so far · about 18 min left", from how
/// fast rows have finished so far (several go at once, and uploads overlap
/// Apple's processing, so it's the pace, not each row's own time).
extension PushProgressSummary {
    /// "6:12 so far · about 18 min left"; nil unless it's running.
    func timeTitle(now: Date) -> String? {
        guard isRunning, let startedAt else { return nil }
        let elapsed = String(localized: "\(ExtrasPushRun.clock(now.timeIntervalSince(startedAt))) so far")
        guard let left = remainingSeconds(now: now) else { return elapsed }
        if left < 60 { return String(localized: "\(elapsed) · less than a minute left") }
        return String(localized: "\(elapsed) · about \(Int((left / 60).rounded(.up))) min left")
    }

    /// About how long the rest takes. Nil until one row went (or failed),
    /// while paused, or once nothing's left; after Cancel Remaining only
    /// the rows in flight are left.
    func remainingSeconds(now: Date) -> TimeInterval? {
        guard isRunning, pausedUntil == nil, let startedAt else { return nil }
        let went = doneCount + failedCount
        guard went > 0 else { return nil }
        let left = isCancelling ? inFlightCount : totalCount - finishedCount
        guard left > 0 else { return nil }
        return max(0, now.timeIntervalSince(startedAt)) / Double(went) * Double(left)
    }
}
