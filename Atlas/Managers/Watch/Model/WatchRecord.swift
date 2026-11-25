//
//  WatchRecord.swift
//  Atlas
//

import Foundation

/// What Look for Improvements remembers of one finding: the last time a
/// check saw it, and where it stands.
struct WatchRecord: Identifiable, Hashable, Codable, Sendable {
    /// As last seen.
    var signal: WatchSignal
    var state: WatchSignalState = .new
    /// The number when the person accepted or dismissed it, which it has to
    /// move away from to come back.
    var decidedValue: Double?
    var firstSeen: Date
    var lastSeen: Date

    var id: String { signal.identity }
}
