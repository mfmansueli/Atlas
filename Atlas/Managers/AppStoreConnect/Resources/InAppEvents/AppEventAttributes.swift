//
//  AppEventAttributes.swift
//  Atlas
//

import Foundation

/// An `appEvents` resource: an In-App Event.
struct AppEventAttributes: Decodable, Sendable {
    struct Schedule: Decodable, Sendable {
        var territories: [String]?
        var publishStart: String?
        var eventStart: String?
        var eventEnd: String?
    }

    var referenceName: String?
    var badge: String?
    var eventState: String?
    var deepLink: String?
    /// `NO_COST_ASSOCIATED` or `IN_APP_PURCHASE`.
    var purchaseRequirement: String?
    var primaryLocale: String?
    var priority: String?
    var purpose: String?
    var territorySchedules: [Schedule]?
    /// The schedules of an event that's over.
    var archivedTerritorySchedules: [Schedule]?
}
