//
//  PriceTestDebugState.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Where a price test DEBUG scene (board 76, `pt-*`) puts Lumen Plus
/// Annual's tests.
enum PriceTestDebugState: Hashable {
    /// No test yet.
    case none
    /// Test a Price open on a region and step, or its confirmation.
    case setup(TerritoryRegion, PriceTestStep, control: PriceTestControlChoice = .automatic, confirming: Bool = false)
    /// Europe −20% waits in Review & Push.
    case queued
    /// Europe −20% on day 9 of 28.
    case running
    /// Running, End Test and Set… for Germany.
    case conflict
    /// Running, End Test Early….
    case stopping
    /// Finished with this verdict; Details open.
    case ready(ResultVerdict, details: Bool = false)
    /// Better, Keep Test Prices… open.
    case keeping
    /// Better, the test prices kept.
    case kept
    /// The assistant's suggested test in Asia Pacific.
    case suggested
}
#endif
