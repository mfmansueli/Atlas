//
//  AppPriceAttributes.swift
//  Atlas
//

import Foundation

/// The fields Atlas reads from an `appPrices` resource
/// (`GET /v1/appPriceSchedules/{id}/manualPrices`): one of the app's own
/// prices, in effect from `startDate` (none: from the start) until
/// `endDate` (none: until further notice). Its point and territory are
/// relationships.
struct AppPriceAttributes: Decodable, Sendable {
    var manual: Bool?
    var startDate: String?
    var endDate: String?
}
