//
//  InAppPurchasePriceScheduleDocument.swift
//  Atlas
//

import Foundation

/// `GET /v2/inAppPurchases/{id}/iapPriceSchedule`: the schedule its prices
/// are read under, and its base territory. A schedule has no attributes,
/// which `AppInformationResourceDocument` requires.
struct InAppPurchasePriceScheduleDocument: Decodable, Sendable {
    struct Schedule: Decodable, Sendable {
        var id: String
        var relationships: [String: AppInformationLinkage]?
    }

    var data: Schedule?

    /// The territory its prices are set in and equalized from, e.g. "USA".
    var baseTerritoryID: String? {
        data?.relationships?["baseTerritory"]?.data?.id
    }
}
