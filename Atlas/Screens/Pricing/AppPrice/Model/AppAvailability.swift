//
//  AppAvailability.swift
//  Atlas
//

import Foundation

/// Where the app is sold: its `appAvailabilities` resource and every
/// country or region under it, by name.
struct AppAvailability: Hashable, Sendable {
    var id: String
    /// Whether countries and regions Apple adds get the app; nil when Apple
    /// didn't say. The API can't change it once the availability exists.
    var availableInNewTerritories: Bool?
    var territories: [AppTerritoryAvailability]

    init(id: String, availableInNewTerritories: Bool?, territories: [AppTerritoryAvailability]) {
        self.id = id
        self.availableInNewTerritories = availableInNewTerritories
        self.territories = territories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var availableCount: Int { territories.count { $0.isAvailable } }

    func territory(_ territoryID: String) -> AppTerritoryAvailability? {
        territories.first { $0.territoryID == territoryID }
    }

    /// The release date of a pre-order, if one is offered anywhere.
    var preOrderReleaseDate: String? {
        territories.first { $0.isPreOrder && $0.isAvailable }?.releaseDate
    }
}
