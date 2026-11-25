//
//  WatchKindStats.swift
//  Atlas
//

import Foundation

/// How one kind of finding fares with the person in one app: its last
/// batches, how often it may come up, and whether the person paused or
/// silenced it.
struct WatchKindStats: Hashable, Codable, Sendable {
    /// Don't Suggest This Again, for this kind in this app.
    var isSilenced = false
    /// Three dismissals in a row: nothing more until the person says Keep
    /// Suggesting.
    var isPaused = false
    /// Keep Suggesting? is to be asked (once).
    var asksKeepSuggesting = false
    var hasAskedKeepSuggesting = false
    var dismissalsInARow = 0
    /// The base interval times this: doubled when the person takes under a
    /// fifth of the last batches.
    var intervalMultiplier = 1
    /// The last batches, oldest first (`WatchBackoff.window` at most).
    var batches: [WatchBatchOutcome] = []
    /// When a run last brought it up.
    var lastSentAt: Date?
}
