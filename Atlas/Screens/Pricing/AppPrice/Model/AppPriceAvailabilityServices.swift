//
//  AppPriceAvailabilityServices.swift
//  Atlas
//

import Foundation

/// What Pricing's App Price and Availability cards (and their MCP tools)
/// read: the app's own price schedule, Apple's price points for it, where
/// it's sold, and every country or region App Store Connect has.
/// `LiveAppPriceAvailabilityServices` reads App Store Connect; tests and
/// DEBUG scenes use canned data.
@MainActor
protocol AppPriceAvailabilityServices {
    /// The price today, or `.notSet` for an app that has never had one.
    func appPrice(for app: StoreApp) async throws -> AppPriceState

    /// Every price the app can have in a territory, Free (0) first.
    func pricePoints(for app: StoreApp, territoryID: String) async throws -> PricePointLadder

    /// Where it's sold, or `.notSet` for an app without an availability.
    func availability(for app: StoreApp) async throws -> AppAvailabilityState

    /// Every country or region App Store Connect has, by name.
    func territories() async throws -> [AppTerritory]
}
