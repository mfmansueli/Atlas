//
//  WatchSignalOutcome.swift
//  Atlas
//

import Foundation

/// What became of one finding sent to an assistant, for its kind's backoff.
enum WatchSignalOutcome: String, Hashable, Codable, Sendable {
    /// The person accepted what came of it, or fixed it.
    case accepted
    /// Accepted after changing it.
    case edited
    case dismissed
    /// Nothing within a week.
    case ignored
}
