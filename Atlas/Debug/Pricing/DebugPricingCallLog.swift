//
//  DebugPricingCallLog.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Counts the price sheets a DEBUG scene asked for, so a scene can answer
/// the first at once and hold the refresh that follows (the skeleton), and
/// notes each read of Apple's price points (the territories asked for).
@MainActor
final class DebugPricingCallLog {
    private(set) var sheetRequests = 0
    private(set) var ladderRequests: [[String]] = []
    /// Products whose ladders a push asked to drop, with the push's date.
    private(set) var forgotten: [(productID: String, before: Date)] = []

    func recordSheetRequest() -> Int {
        sheetRequests += 1
        return sheetRequests
    }

    func recordLadderRequest(_ territoryIDs: [String]) {
        ladderRequests.append(territoryIDs)
    }

    func recordForget(productID: String, before date: Date) {
        forgotten.append((productID, date))
    }
}
#endif
