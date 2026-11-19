//
//  TimeLeftEstimate.swift
//  Atlas
//

import Foundation

/// "about 6 min left" for a job in the menu bar's menu, from how fast it
/// has gone so far. Says nothing until there's enough to go on: the first
/// seconds, or less than 5% done, would guess wildly.
enum TimeLeftEstimate {
    static let minimumElapsed: TimeInterval = 5
    static let minimumFraction = 0.05

    /// Seconds left, or nil while it's too early to say or once done.
    static func seconds(startedAt: Date, fraction: Double, now: Date) -> TimeInterval? {
        let elapsed = now.timeIntervalSince(startedAt)
        guard elapsed >= minimumElapsed, fraction >= minimumFraction, fraction < 1 else { return nil }
        return elapsed * (1 - fraction) / fraction
    }

    /// "about 1 min left", "about 2 h left"; nil as `seconds` is.
    static func text(startedAt: Date, fraction: Double, now: Date) -> String? {
        seconds(startedAt: startedAt, fraction: fraction, now: now).map(text(seconds:))
    }

    static func text(seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        guard minutes >= 120 else { return String(localized: "about \(minutes) min left") }
        return String(localized: "about \(Int((Double(minutes) / 60).rounded())) h left")
    }
}
