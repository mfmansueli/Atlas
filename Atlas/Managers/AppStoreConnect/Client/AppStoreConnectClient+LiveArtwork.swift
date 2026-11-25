//
//  AppStoreConnectClient+LiveArtwork.swift
//  Atlas
//

import Foundation

/// The header and search results artwork a version localization's page
/// shows now, with Apple's image URLs.
extension AppStoreConnectClient {
    func liveStoreArtwork(localizationID: String) async throws -> LiveStoreArtwork {
        let data = try await fetch(AssetLibraryRequests.artworkPlacementsPath(localizationID: localizationID)).data
        return try LiveStoreArtwork(images: AssetLibraryRequests.placedArtwork(in: data))
    }
}
