//
//  AppTerritoryAvailability.swift
//  Atlas
//

import Foundation

/// Whether the app is sold in one country or region
/// (`territoryAvailabilities`), its release date and pre-order there.
struct AppTerritoryAvailability: Identifiable, Hashable, Sendable {
    /// The `territoryAvailabilities` ID, which a `PATCH` changes.
    var id: String
    /// Alpha-3, e.g. "BRA".
    var territoryID: String
    var isAvailable: Bool
    /// "2026-12-20"; nil when it isn't set.
    var releaseDate: String?
    var isPreOrder = false
    /// Apple's statuses there, e.g. `AVAILABLE` or `CANNOT_SELL_CASINO`.
    var contentStatuses: [String] = []

    var name: String { AppTerritory.name(of: territoryID) }
}
