//
//  AppAvailabilitySetup.swift
//  Atlas
//

import Foundation

/// The app's first availability, as Set Up Availability… or
/// `propose_availability` chooses it: the countries and regions it's sold
/// in (every one App Store Connect has, by default), whether new ones get
/// it, and an optional pre-order until its release date.
struct AppAvailabilitySetup: Hashable, Sendable {
    /// Every territory App Store Connect has, alpha-3.
    var allTerritoryIDs: [String]
    /// The ones the app is sold in.
    var availableTerritoryIDs: Set<String>
    var availableInNewTerritories = true
    /// "2026-12-20": offered for pre-order until that day, when it's
    /// released; nil releases it as soon as App Review approves it.
    var preOrderReleaseDate: String?

    /// Sold everywhere, new countries and regions too.
    static func everywhere(_ territoryIDs: [String]) -> AppAvailabilitySetup {
        AppAvailabilitySetup(allTerritoryIDs: territoryIDs, availableTerritoryIDs: Set(territoryIDs))
    }

    var isEverywhere: Bool {
        !allTerritoryIDs.isEmpty && Set(allTerritoryIDs).isSubset(of: availableTerritoryIDs)
    }

    var availableCount: Int {
        allTerritoryIDs.count { availableTerritoryIDs.contains($0) }
    }

    /// "Every country or region (175)", "12 of 175 countries or regions".
    var territoriesText: String {
        if isEverywhere { return String(localized: "Every country or region (\(allTerritoryIDs.count))") }
        let names = allTerritoryIDs.filter { availableTerritoryIDs.contains($0) }.map(AppTerritory.name(of:)).sorted()
        let count = String(localized: "\(availableCount) of \(allTerritoryIDs.count) countries or regions")
        guard names.count <= 4 else { return count }
        return "\(count): \(names.formatted(.list(type: .and)))"
    }
}
