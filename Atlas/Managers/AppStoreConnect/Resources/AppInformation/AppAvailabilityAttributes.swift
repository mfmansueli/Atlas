//
//  AppAvailabilityAttributes.swift
//  Atlas
//

import Foundation

/// The attributes of an `appAvailabilities` resource
/// (`GET /v1/apps/{id}/appAvailabilityV2`). Only its ID is used: it leads
/// to the app's countries and regions.
struct AppAvailabilityAttributes: Decodable, Sendable {
    var availableInNewTerritories: Bool?
}
