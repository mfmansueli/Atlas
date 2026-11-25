//
//  WatchArchive.swift
//  Atlas
//

import Foundation

/// Look for Improvements' record of one app, kept as `watch-<appID>.json`:
/// every finding's state, each kind's backoff, and the runs it started.
struct WatchArchive: Hashable, Codable, Sendable {
    /// By `WatchSignal.identity`.
    var records: [String: WatchRecord] = [:]
    /// By `WatchSignalKind.rawValue`.
    var kinds: [String: WatchKindStats] = [:]
    /// Oldest first.
    var history: [WatchHistoryEntry] = []

    /// Runs kept for the History, the oldest going first.
    static let historyLimit = 60

    func stats(for kind: WatchSignalKind) -> WatchKindStats {
        kinds[kind.rawValue] ?? WatchKindStats()
    }

    mutating func updateStats(for kind: WatchSignalKind, _ change: (inout WatchKindStats) -> Void) {
        var stats = stats(for: kind)
        change(&stats)
        kinds[kind.rawValue] = stats
    }

    mutating func append(_ entry: WatchHistoryEntry) {
        history.append(entry)
        if history.count > Self.historyLimit { history.removeFirst(history.count - Self.historyLimit) }
    }

    mutating func updateEntry(_ id: WatchHistoryEntry.ID, _ change: (inout WatchHistoryEntry) -> Void) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        change(&history[index])
    }
}
