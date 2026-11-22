//
//  TerritoryAvailabilityAttributes.swift
//  Atlas
//

import Foundation

/// The attributes of a `territoryAvailabilities` resource: whether the app
/// is sold in one country or region, and Apple's `contentStatuses` there,
/// e.g. `TRADER_STATUS_NOT_PROVIDED` or `ICP_NUMBER_MISSING`. The statuses
/// stay strings, so one this build doesn't know never fails the read.
struct TerritoryAvailabilityAttributes: Decodable, Sendable {
    var available: Bool?
    var contentStatuses: [String]?
    /// Pricing's availability reads these too: the day it's released there
    /// ("2026-12-20"), and whether it's offered for pre-order until then.
    var releaseDate: String?
    var preOrderEnabled: Bool?
}
