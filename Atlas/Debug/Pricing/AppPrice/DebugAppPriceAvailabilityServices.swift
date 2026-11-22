//
//  DebugAppPriceAvailabilityServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// `AppPriceAvailabilityServices` for DEBUG scenes and tests: Quiet Timer
/// has no price and no availability yet (App Store Connect's "Add Pricing"
/// and "Set Up Availability"); every other sample app is free, or $2.99
/// for Tempo Metronome, sold everywhere but China mainland. Never contacts
/// App Store Connect.
@MainActor
struct DebugAppPriceAvailabilityServices: AppPriceAvailabilityServices {
    var error: AppStoreConnectError?
    /// Apps with neither a price nor an availability.
    var unsetAppIDs: Set<StoreApp.ID> = [DebugFixtures.AppID.quiet]
    /// The sheet a scene opens once the cards have read.
    var opens: AppPriceDebugSheet?

    /// The ladder's prices in the territory's currency, Free first.
    static let tiers: [Decimal] = [
        "0", "0.29", "0.49", "0.99", "1.49", "1.99", "2.49", "2.99", "3.99", "4.99", "5.99", "6.99", "7.99", "8.99", "9.99",
        "14.99", "19.99", "24.99", "29.99", "49.99", "99.99",
    ].compactMap { Decimal(string: $0) }

    func appPrice(for app: StoreApp) async throws -> AppPriceState {
        if let error { throw error }
        guard !unsetAppIDs.contains(app.id) else { return .notSet }
        let price = app.id == DebugFixtures.AppID.tempo ? Decimal(string: "2.99") ?? 0 : 0
        let point = Self.ladder(territoryID: "USA").points.first { $0.customerPrice == price }
        return .set(AppCurrentPrice(scheduleID: "debug-schedule-\(app.id)", baseTerritoryID: "USA", currencyCode: "USD", point: point))
    }

    func pricePoints(for _: StoreApp, territoryID: String) async throws -> PricePointLadder {
        if let error { throw error }
        return Self.ladder(territoryID: territoryID)
    }

    func availability(for app: StoreApp) async throws -> AppAvailabilityState {
        if let error { throw error }
        guard !unsetAppIDs.contains(app.id) else { return .notSet }
        let territories = TerritoryCatalog.standard.territories.map { territory in
            AppTerritoryAvailability(
                id: "debug-ta-\(app.id)-\(territory.id)",
                territoryID: territory.id,
                isAvailable: territory.id != "CHN",
                contentStatuses: territory.id == "CHN" ? ["ICP_NUMBER_MISSING"] : ["AVAILABLE"]
            )
        }
        return .set(AppAvailability(id: "debug-availability-\(app.id)", availableInNewTerritories: true, territories: territories))
    }

    func territories() async throws -> [AppTerritory] {
        if let error { throw error }
        return AppTerritory.sorted(TerritoryCatalog.standard.territories.map { AppTerritory(id: $0.id, currencyCode: $0.currencyCode) })
    }

    /// Made-up points: the tiers in the territory's currency, with 70% of
    /// the price before its tax as proceeds.
    static func ladder(territoryID: String) -> PricePointLadder {
        let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
        let points = tiers.map { price in
            let beforeTax = price / (1 + (territory?.taxRate ?? 0))
            let proceeds = (beforeTax * 7 / 10).rounded(scale: 2)
            return PricePoint(customerPrice: price, proceeds: proceeds, appStoreConnectID: "debug-\(territoryID)-\(price)")
        }
        return PricePointLadder(territoryID: territoryID, currencyCode: territory?.currencyCode ?? "USD", points: points)
    }
}
#endif
