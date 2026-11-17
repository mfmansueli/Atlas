//
//  DebugAppInformationContent+Compliance.swift
//  Atlas
//

#if DEBUG
import Foundation

extension DebugAppInformationContent {
    /// The trader details the App Compliance scenes show, as if typed
    /// before deciding.
    static let traderDetails = TraderDetails(
        name: "Northpier Studio Ltd",
        address: "14 Harbour Road, Dublin 2, D02 X285, Ireland",
        phone: "+353 1 555 0142",
        email: "support@northpier.dev"
    )

    /// A number that reads like an ICP Filing Number.
    static let icpNumber = "沪ICP备2026012345号-2A"

    /// Lumen Journal as App Store Connect's API shows it for App
    /// Compliance: sold everywhere, with no trader status in the EU and no
    /// ICP Filing Number in China mainland.
    static var compliance: ComplianceContent {
        ComplianceContent(territories: TerritoryCatalog.standard.territories.map { territory in
            ComplianceTerritory(id: availabilityID(territory.id), territoryID: territory.id, isAvailable: true, statuses: lumenStatuses(territory.id))
        })
    }

    private static func lumenStatuses(_ territoryID: String) -> Set<String> {
        if ComplianceRegion.europeanUnion.contains(territoryID) { return [ComplianceContent.traderNotProvided, "CANNOT_SELL"] }
        return territoryID == ComplianceRegion.chinaMainland ? [ComplianceContent.icpMissing] : ["AVAILABLE"]
    }

    /// Any other sample app: sold everywhere, nothing missing.
    static var settledCompliance: ComplianceContent {
        ComplianceContent(territories: TerritoryCatalog.standard.territories.map {
            ComplianceTerritory(id: availabilityID($0.id), territoryID: $0.id, isAvailable: true, statuses: ["AVAILABLE"])
        })
    }

    static func availabilityID(_ territoryID: String) -> String {
        "lumen-availability-\(territoryID)"
    }
}
#endif
