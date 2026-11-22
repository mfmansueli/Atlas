//
//  AppInformationChangeBuilder+Compliance.swift
//  Atlas
//

import Foundation

// App Compliance: the one answer Apple's API takes is where the app is
// sold. "Stop selling in China mainland" is a `PATCH` of that country's
// `territoryAvailabilities`, under the same change id as Pricing's
// availability (`propose_availability`, `AppAvailabilityChangeBuilder`):
// `appAvailability.<appID>.<territoryID>`. Whichever queues it, there's
// one change, and each page reads it back from either section.
extension AppInformationChangeBuilder {
    /// `appAvailability.<appID>.<territoryID>`, as Pricing names a country's
    /// availability change.
    func stopSellingChangeID(_ territoryID: String) -> String {
        "appAvailability.\(appID).\(territoryID)"
    }

    /// The id App Compliance gave the change before it shared Pricing's,
    /// for changes queued then.
    func legacyStopSellingChangeID(_ territoryID: String) -> String {
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

    /// The queued changes that take `territoryID` off sale: App
    /// Compliance's or Pricing's, never one that puts it on sale.
    func stopSellingChangeIDs(_ territoryID: String, in changes: [PendingChange]) -> [PendingChange.ID] {
        [stopSellingChangeID(territoryID), legacyStopSellingChangeID(territoryID)].filter { id in
            guard let change = Self.change(id, in: changes) else { return false }
            return Self.document(of: change)?.attribute("available")?.boolValue == false
        }
    }

    /// Whether taking `territoryID` off sale is queued. `changes` are all
    /// the app's, since Pricing's availability changes are in its section.
    func stopsSelling(in territoryID: String, with changes: [PendingChange]) -> Bool {
        !stopSellingChangeIDs(territoryID, in: changes).isEmpty
    }
}
