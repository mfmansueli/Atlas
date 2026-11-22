//
//  LiveAppPriceAvailabilityServices.swift
//  Atlas
//

import Foundation

/// The real `AppPriceAvailabilityServices`, read from App Store Connect.
/// Apple's territories are read once per account session.
@MainActor
final class LiveAppPriceAvailabilityServices: AppPriceAvailabilityServices {
    let client: AppStoreConnectClient
    var today: () -> Date = { .now }
    private var territoryList: [AppTerritory]?

    init(client: AppStoreConnectClient) {
        self.client = client
    }

    func appPrice(for app: StoreApp) async throws -> AppPriceState {
        guard let schedule = try await client.appPriceSchedule(appID: app.id), let scheduleID = schedule.data?.id else { return .notSet }
        let prices = try await client.appPrices(scheduleID: scheduleID)
        let current = AppPriceAvailabilityMapper.currentPrice(
            scheduleID: scheduleID,
            baseTerritoryID: schedule.baseTerritoryID ?? AppTerritory.unitedStates.id,
            prices: prices,
            today: AppAvailabilityRules.day(today(), calendar: Self.gmt)
        )
        // A schedule with no price in effect anywhere sells nothing yet.
        return current.point == nil && current.otherManualTerritoryIDs.isEmpty && current.laterChangeCount == 0 ? .notSet : .set(current)
    }

    func pricePoints(for app: StoreApp, territoryID: String) async throws -> PricePointLadder {
        let document = try await client.appPricePoints(appID: app.id, territoryID: territoryID)
        return AppPriceAvailabilityMapper.ladder(document, territoryID: territoryID)
    }

    func availability(for app: StoreApp) async throws -> AppAvailabilityState {
        guard let availability = try await client.appAvailability(appID: app.id) else { return .notSet }
        let territories = try await client.saleTerritoryAvailabilities(availabilityID: availability.id)
        return .set(AppPriceAvailabilityMapper.availability(
            id: availability.id,
            availableInNewTerritories: availability.attributes.availableInNewTerritories,
            territories: territories
        ))
    }

    func territories() async throws -> [AppTerritory] {
        if let territoryList { return territoryList }
        let list = try await AppPriceAvailabilityMapper.territories(client.territories())
        guard !list.isEmpty else { throw AppStoreConnectError.unexpectedPayload }
        territoryList = list
        return list
    }

    /// Apple's schedule dates are calendar days in UTC.
    private static let gmt: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
}
