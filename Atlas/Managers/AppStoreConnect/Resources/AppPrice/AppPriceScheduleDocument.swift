//
//  AppPriceScheduleDocument.swift
//  Atlas
//

import Foundation

/// `GET /v1/apps/{id}/appPriceSchedule`: the schedule the app's own price
/// is read under, and its base territory. A schedule has no attributes,
/// which `AppInformationResourceDocument` requires.
struct AppPriceScheduleDocument: Decodable, Sendable {
    struct Schedule: Decodable, Sendable {
        var id: String
        var relationships: [String: AppInformationLinkage]?
    }

    var data: Schedule?

    /// The territory its price is set in and equalized from, e.g. "USA".
    var baseTerritoryID: String? {
        data?.relationships?["baseTerritory"]?.data?.id
    }
}
