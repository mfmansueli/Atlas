//
//  PushItemOutcome.swift
//  Atlas
//

import Foundation

/// What happened to one item of a push, for the loop that sends them.
enum PushItemOutcome: Sendable {
    case pushed(StoreApp.ID)
    case failed(String, stop: String?)
    /// Not sent, and the rest stop too (rate limit, offline).
    case stopped(String)
    case skipped
}
