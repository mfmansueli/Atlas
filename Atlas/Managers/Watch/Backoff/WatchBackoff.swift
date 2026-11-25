//
//  WatchBackoff.swift
//  Atlas
//

import Foundation

/// How often each kind of finding may come up in an app, from what the
/// person made of the last ones: under a fifth taken over the last five
/// batches doubles the kind's interval (a fifth or more halves it back);
/// three dismissals in a row pause the kind and ask Keep Suggesting? once.
enum WatchBackoff {
    /// Batches the share is worked out over.
    static let window = 5
    static let minimumShare = 0.2
    static let dismissalsToPause = 3
    static let longestMultiplier = 16
    /// How long a run's findings have to be decided before they count as
    /// ignored.
    static let settleTime: TimeInterval = 7 * 24 * 3600

    /// When the kind may come up again; nil when it never came up.
    static func nextDate(for kind: WatchSignalKind, stats: WatchKindStats) -> Date? {
        stats.lastSentAt.map { $0.addingTimeInterval(interval(for: kind, stats: stats)) }
    }

    static func interval(for kind: WatchSignalKind, stats: WatchKindStats) -> TimeInterval {
        kind.baseInterval * Double(max(1, stats.intervalMultiplier))
    }

    /// One run's outcomes for the kind, in the order they were decided.
    static func record(_ outcomes: [WatchSignalOutcome], runID: UUID, in stats: inout WatchKindStats) {
        guard !outcomes.isEmpty else { return }
        stats.batches.append(WatchBatchOutcome(runID: runID, outcomes: outcomes))
        if stats.batches.count > window { stats.batches.removeFirst(stats.batches.count - window) }
        for outcome in outcomes {
            switch outcome {
            case .dismissed: stats.dismissalsInARow += 1
            case .accepted, .edited: stats.dismissalsInARow = 0
            case .ignored: break
            }
        }
        if stats.dismissalsInARow >= dismissalsToPause, !stats.isPaused {
            stats.isPaused = true
            if !stats.hasAskedKeepSuggesting { stats.asksKeepSuggesting = true }
        }
        guard stats.batches.count >= window else { return }
        let total = stats.batches.reduce(0) { $0 + $1.total }
        let taken = stats.batches.reduce(0) { $0 + $1.taken }
        let share = total > 0 ? Double(taken) / Double(total) : 0
        if share < minimumShare {
            stats.intervalMultiplier = min(longestMultiplier, max(1, stats.intervalMultiplier) * 2)
        } else {
            stats.intervalMultiplier = max(1, stats.intervalMultiplier / 2)
        }
    }

    /// The person answered Keep Suggesting?: yes takes the pause away; no
    /// is Don't Suggest This Again. Either way it isn't asked again.
    static func keepSuggesting(_ keeps: Bool, stats: inout WatchKindStats) {
        stats.asksKeepSuggesting = false
        stats.hasAskedKeepSuggesting = true
        stats.isPaused = false
        stats.dismissalsInARow = 0
        if !keeps { stats.isSilenced = true }
    }
}
