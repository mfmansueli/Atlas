//
//  WatchHistoryEntry.swift
//  Atlas
//

import Foundation

/// One Look for Improvements run, for the History the person reads later:
/// when, which app, what it was sent, how it ended and what it proposed.
struct WatchHistoryEntry: Identifiable, Hashable, Codable, Sendable {
    /// The Claude Code run's id, which its proposals carry
    /// (`ChangeOrigin.watch`).
    var id: UUID
    var appID: StoreApp.ID
    var appName: String
    var startedAt: Date
    var endedAt: Date?
    var signals: [WatchSignal]
    var result: WatchRunResult = .working
    /// What it sent through Atlas's tools.
    var proposals: [WatchProposal] = []
    /// Its findings' outcomes went into their kinds' backoff.
    var isSettled = false
}
