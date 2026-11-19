//
//  PushLoopEvent.swift
//  Atlas
//

import Foundation

/// What wakes a push's send loop: changes that finished, or one Apple took
/// over (uploaded, now processing), whose place goes to the next change.
enum PushLoopEvent: Sendable {
    case finished([(Int, PushItemOutcome)])
    case waitingOnApple(Int)
}
