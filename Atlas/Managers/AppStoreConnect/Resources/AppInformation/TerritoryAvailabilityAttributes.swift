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
}
