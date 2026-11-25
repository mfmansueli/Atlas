//
//  ExtrasPushRun+Removal.swift
//  Atlas
//

import Foundation

/// A header or search image deleted on the Screenshots page: every
/// placement of its types comes off the language's page, in every group.
/// The asset stays in the library (the App Asset Library sheet deletes
/// leftovers).
extension ExtrasPushRun {
    func removePlacements(of item: ExtrasPushItem, placementTypes: [String]) async throws {
        let library = environment.library
        for placementType in placementTypes {
            let placements = try await call {
                try await library.assetLibraryPlacements(localizationID: item.localizationID, placementType: placementType, placementGroup: nil)
            }
            for placement in placements where (placement.placementType ?? placementType) == placementType {
                do {
                    try await call { try await library.deleteAssetLibraryPlacement(id: placement.id) }
                } catch AppStoreConnectError.notFound {
                    continue
                }
            }
        }
    }
}
