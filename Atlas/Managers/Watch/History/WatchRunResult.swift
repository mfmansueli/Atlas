//
//  WatchRunResult.swift
//  Atlas
//

import Foundation

/// How a Look for Improvements run ended.
enum WatchRunResult: Hashable, Codable, Sendable {
    case working
    case finished
    /// The person stopped it.
    case stopped
    /// Claude Code ran out of usage for now: no runs for a while.
    case usageLimit
    /// Atlas quit while it ran.
    case interrupted
    case failed(reason: String)

    var isWorking: Bool { self == .working }

    /// "working", "finished"…, for the debug scene.
    var key: String {
        switch self {
        case .working: "working"
        case .finished: "finished"
        case .stopped: "stopped"
        case .usageLimit: "usageLimit"
        case .interrupted: "interrupted"
        case .failed: "failed"
        }
    }
}
