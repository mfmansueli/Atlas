//
//  PriceTestState.swift
//  Atlas
//

import Foundation

/// Where a price test is, as Atlas last knew it. Whether it's still
/// running or waiting for its result follows from the date
/// (`PriceTestPhase`).
enum PriceTestState: String, Hashable, Codable, Sendable {
    /// Both price changes wait in Review & Push.
    case queued
    /// Pushed: the test price is live until day 28, then the old prices
    /// come back by themselves.
    case running
    /// Ended before day 28: no result.
    case endedEarly
    /// Finished, and the person keeps the test prices.
    case kept
    /// Finished, and the person read the result (Done).
    case done
}
