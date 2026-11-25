//
//  PriceTestPhase.swift
//  Atlas
//

import Foundation

/// What a price test's card in Results shows.
enum PriceTestPhase: Hashable, Sendable {
    /// Waits in Review & Push.
    case queued
    /// "Day 9 of 28": no result before the end.
    case running(day: Int)
    /// The old prices are back; Apple's reports don't cover the 28 days yet.
    case waitingForResult
    case ready(PriceTestResult)
    /// Keep Test Prices… queued the test prices as a price change.
    case kept
    /// Ended early: no result.
    case ended
    /// Done: the card goes.
    case done
}
