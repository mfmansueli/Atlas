//
//  AppInformationChangeBuilder+Compliance.swift
//  Atlas
//

import Foundation

// App Compliance: the one answer Apple's API takes is where the app is
// sold. "Stop selling in China mainland" is a `PATCH` of that country's
// `territoryAvailabilities`.
extension AppInformationChangeBuilder {
    func stopSellingChangeID(_ territoryID: String) -> String {
        changeID(.appCompliance, "availability.\(territoryID)")
    }

    /// Takes the app off sale in one country or region. Nil when it isn't
    /// sold there.
    func stopSellingChange(_ territory: ComplianceTerritory, source: ChangeSource = .you) -> PendingChange? {
        guard territory.isSold else { return nil }
        let place = TerritoryCatalog.standard.territory(alpha3: territory.territoryID)
        let request = { (isAvailable: Bool) in
            Self.patch("territoryAvailabilities", id: territory.id, attributes: ["available": .bool(isAvailable)])
        }
        return PendingChange(
            id: stopSellingChangeID(territory.territoryID),
            appID: appID,
            section: .appInformation,
            group: group(.appCompliance),
            title: String(localized: "Availability · \(place?.name ?? territory.territoryID)"),
            flagRegion: place?.alpha2,
            oldValue: String(localized: "Available"),
            newValue: String(localized: "Not available"),
            source: source,
            requests: [request(false)],
            restoreRequests: [request(true)]
        )
    }

    /// Whether taking `territoryID` off sale is queued.
    func stopsSelling(in territoryID: String, with changes: [PendingChange]) -> Bool {
        Self.change(stopSellingChangeID(territoryID), in: changes) != nil
    }
}
