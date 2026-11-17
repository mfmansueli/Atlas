//
//  ComplianceContentLoader.swift
//  Atlas
//

import Foundation

/// Reads what App Store Connect's API has for App Compliance: the app's
/// countries and regions with Apple's statuses. An app without
/// availability yet has no countries to check.
struct ComplianceContentLoader: Sendable {
    let client: AppStoreConnectClient

    func content(for app: StoreApp) async throws -> ComplianceContent {
        guard let availabilityID = try await client.appAvailabilityID(appID: app.id) else {
            return ComplianceContent(territories: nil)
        }
        let resources = try await client.territoryAvailabilities(availabilityID: availabilityID)
        return ComplianceContent(territories: resources.compactMap(Self.territory))
    }

    // MARK: - Mapping

    static func territory(_ resource: AppInformationResourceDocument<TerritoryAvailabilityAttributes>.Resource) -> ComplianceTerritory? {
        guard let territoryID = resource.relationshipID("territory") ?? territoryID(inAvailabilityID: resource.id) else { return nil }
        return ComplianceTerritory(
            id: resource.id,
            territoryID: territoryID,
            isAvailable: resource.attributes.available ?? false,
            statuses: Set(resource.attributes.contentStatuses ?? [])
        )
    }

    /// The territory inside a `territoryAvailabilities` ID, which is
    /// base64 for `{"s":"<app>","t":"CHN"}`: used when the response leaves
    /// the linkage out.
    static func territoryID(inAvailabilityID id: String) -> String? {
        var base64 = id.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["t"] as? String
    }
}
