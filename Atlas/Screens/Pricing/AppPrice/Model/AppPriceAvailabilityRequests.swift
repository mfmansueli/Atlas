//
//  AppPriceAvailabilityRequests.swift
//  Atlas
//

import Foundation

/// The App Store Connect writes behind the app's price and availability
/// changes (OpenAPI 4.6.1), and how to read them back from a queued change.
///
/// - Price: `POST /v1/appPriceSchedules`, the app, its base territory and
///   one manual price created inline (`${price1}`) on Apple's price point,
///   with no start date, so it starts as soon as Apple processes it. A new
///   schedule replaces the whole old one; every other territory gets
///   Apple's equalized price.
/// - First availability: `POST /v2/appAvailabilities` with every
///   territory created inline (`${USA}`), available or not, its release
///   date and pre-order.
/// - One country or region: `PATCH /v1/territoryAvailabilities/{id}`
///   `{available}`, as App Compliance's "Stop selling" sends it.
enum AppPriceAvailabilityRequests {
    static let priceSchedulesPath = "/v1/appPriceSchedules"
    static let availabilitiesPath = "/v2/appAvailabilities"
    static let territoryAvailabilitiesPath = "/v1/territoryAvailabilities/"

    static func priceSchedule(appID: String, baseTerritoryID: String, pricePointID: String) -> PushRequest {
        let localID = "${price1}"
        let body: [String: Any] = [
            "data": [
                "type": "appPriceSchedules",
                "relationships": [
                    "app": ["data": ["type": "apps", "id": appID]],
                    "baseTerritory": ["data": ["type": "territories", "id": baseTerritoryID]],
                    "manualPrices": ["data": [["type": "appPrices", "id": localID]]],
                ],
            ],
            "included": [[
                "type": "appPrices",
                "id": localID,
                "attributes": ["startDate": NSNull()],
                "relationships": ["appPricePoint": ["data": ["type": "appPricePoints", "id": pricePointID]]],
            ]],
        ]
        return PushRequest(method: .post, path: priceSchedulesPath, body: encoded(body))
    }

    static func availability(appID: String, setup: AppAvailabilitySetup) -> PushRequest {
        let included: [[String: Any]] = setup.allTerritoryIDs.map { territoryID in
            let isAvailable = setup.availableTerritoryIDs.contains(territoryID)
            var attributes: [String: Any] = ["available": isAvailable]
            if isAvailable, let releaseDate = setup.preOrderReleaseDate {
                attributes["releaseDate"] = releaseDate
                attributes["preOrderEnabled"] = true
            }
            return [
                "type": "territoryAvailabilities",
                "id": localID(territoryID),
                "attributes": attributes,
                "relationships": ["territory": ["data": ["type": "territories", "id": territoryID]]],
            ]
        }
        let body: [String: Any] = [
            "data": [
                "type": "appAvailabilities",
                "attributes": ["availableInNewTerritories": setup.availableInNewTerritories],
                "relationships": [
                    "app": ["data": ["type": "apps", "id": appID]],
                    "territoryAvailabilities": [
                        "data": setup.allTerritoryIDs.map { ["type": "territoryAvailabilities", "id": localID($0)] },
                    ],
                ],
            ],
            "included": included,
        ]
        return PushRequest(method: .post, path: availabilitiesPath, body: encoded(body))
    }

    static func territory(_ territoryAvailabilityID: String, available: Bool) -> PushRequest {
        AppInformationChangeBuilder.patch("territoryAvailabilities", id: territoryAvailabilityID, attributes: ["available": .bool(available)])
    }

    // MARK: - Reading queued requests

    /// The base territory and price point a queued price schedule sets.
    static func priceSchedule(in request: PushRequest) -> (baseTerritoryID: String, pricePointID: String)? {
        guard request.method == .post, request.path == priceSchedulesPath, let object = object(request),
              let relationships = (object["data"] as? [String: Any])?["relationships"] as? [String: Any],
              let base = ((relationships["baseTerritory"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String,
              let price = (object["included"] as? [[String: Any]])?.first,
              let point = (((price["relationships"] as? [String: Any])?["appPricePoint"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String
        else { return nil }
        return (base, point)
    }

    /// The setup a queued first availability sends.
    static func availabilitySetup(in request: PushRequest) -> AppAvailabilitySetup? {
        guard request.method == .post, request.path == availabilitiesPath, let object = object(request),
              let data = object["data"] as? [String: Any],
              let included = object["included"] as? [[String: Any]]
        else { return nil }
        var setup = AppAvailabilitySetup(allTerritoryIDs: [], availableTerritoryIDs: [])
        setup.availableInNewTerritories = (data["attributes"] as? [String: Any])?["availableInNewTerritories"] as? Bool ?? true
        for item in included {
            guard let territoryID = (((item["relationships"] as? [String: Any])?["territory"] as? [String: Any])?["data"] as? [String: Any])?["id"]
                as? String else { continue }
            let attributes = item["attributes"] as? [String: Any] ?? [:]
            setup.allTerritoryIDs.append(territoryID)
            if attributes["available"] as? Bool == true { setup.availableTerritoryIDs.insert(territoryID) }
            if let releaseDate = attributes["releaseDate"] as? String { setup.preOrderReleaseDate = releaseDate }
        }
        return setup
    }

    /// The territory availability a `PATCH` changes, and to what.
    static func territoryWrite(in request: PushRequest) -> (territoryAvailabilityID: String, available: Bool)? {
        guard request.method == .patch, request.path.hasPrefix(territoryAvailabilitiesPath), let object = object(request),
              let available = ((object["data"] as? [String: Any])?["attributes"] as? [String: Any])?["available"] as? Bool
        else { return nil }
        return (String(request.path.dropFirst(territoryAvailabilitiesPath.count)), available)
    }

    // MARK: - Private

    private static func localID(_ territoryID: String) -> String {
        "${\(territoryID)}"
    }

    private static func object(_ request: PushRequest) -> [String: Any]? {
        request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    private static func encoded(_ body: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }
}
