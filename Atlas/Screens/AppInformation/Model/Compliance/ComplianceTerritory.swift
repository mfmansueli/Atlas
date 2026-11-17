//
//  ComplianceTerritory.swift
//  Atlas
//

import Foundation

/// One country or region's availability as App Store Connect has it, with
/// Apple's notes on what keeps the app from being sold there.
struct ComplianceTerritory: Identifiable, Hashable, Sendable {
    /// The `territoryAvailabilities` resource: what a write changes.
    var id: String
    /// App Store Connect's territory ID, e.g. `CHN`.
    var territoryID: String
    /// The person chose to sell there.
    var isAvailable: Bool
    /// Apple's `contentStatuses`, e.g. `ICP_NUMBER_MISSING`.
    var statuses: Set<String> = []

    /// Apple's status while it takes the app off sale there.
    static let leavingStatus = "PROCESSING_TO_NOT_AVAILABLE"

    /// Sold there, and not on its way out: a country Apple is still
    /// taking off sale after a push no longer counts.
    var isSold: Bool { isAvailable && !statuses.contains(Self.leavingStatus) }
}
