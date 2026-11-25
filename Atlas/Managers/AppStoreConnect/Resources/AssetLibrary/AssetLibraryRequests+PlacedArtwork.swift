//
//  AssetLibraryRequests+PlacedArtwork.swift
//  Atlas
//

import Foundation

/// Reading the header and search images a page shows: its placements of
/// both types with their images, whose `imageAsset` has the URL to draw.
extension AssetLibraryRequests {
    /// `GET /v1/appStoreVersionLocalizations/{id}/placements` of the header
    /// and search types, with the image each shows.
    static func artworkPlacementsPath(localizationID: String) -> String {
        let types = [AutopilotArtworkKind.headerPlacement, AutopilotArtworkKind.searchPlacement].joined(separator: "%2C")
        return "/v1/appStoreVersionLocalizations/\(localizationID)/placements?filter%5BplacementType%5D=\(types)"
            + "&include=image&limit=200"
    }

    /// Each placed image with its URL; placements without an image (a
    /// video, or one still processing) are left out.
    static func placedArtwork(in data: Data) throws -> [LiveArtworkImage] {
        let page: ScreenshotAPIDocument<AssetLibraryPlacementAttributes, AssetLibraryFileAttributes>
        do {
            page = try JSONDecoder().decode(ScreenshotAPIDocument<AssetLibraryPlacementAttributes, AssetLibraryFileAttributes>.self, from: data)
        } catch {
            throw AppStoreConnectError.unexpectedPayload
        }
        let images = Dictionary((page.included ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return page.data.compactMap { placement -> LiveArtworkImage? in
            guard let type = placement.attributes?.placementType, StoreArtworkPlace(placementType: type) != nil,
                  let imageID = placement.related(AssetLibraryMedia.image.relationship).first?.id,
                  let image = images[imageID]?.attributes?.image, let template = image.templateUrl else { return nil }
            let size = image.width.flatMap { width in image.height.map { PixelSize(width: width, height: $0) } }
            return LiveArtworkImage(
                placementID: placement.id, placementType: type, placementGroup: placement.attributes?.placementGroup,
                templateURL: template, pixelSize: size
            )
        }
    }
}
