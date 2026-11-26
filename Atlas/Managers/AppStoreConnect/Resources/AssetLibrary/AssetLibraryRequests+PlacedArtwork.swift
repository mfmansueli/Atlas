//
//  AssetLibraryRequests+PlacedArtwork.swift
//  Atlas
//

import Foundation

/// Reading the header and search artwork a page shows: its placements of
/// both types with the asset each shows. A still is an image, whose
/// `imageAsset` has the URL to draw; a moving one (the motion loop a push
/// sends in place of the still) is a video, drawn by its poster frame.
extension AssetLibraryRequests {
    /// `GET /v1/appStoreVersionLocalizations/{id}/placements` of the header
    /// and search types, with the image or video each shows.
    static func artworkPlacementsPath(localizationID: String) -> String {
        let types = [AutopilotArtworkKind.headerPlacement, AutopilotArtworkKind.searchPlacement].joined(separator: "%2C")
        return "/v1/appStoreVersionLocalizations/\(localizationID)/placements?filter%5BplacementType%5D=\(types)"
            + "&include=image,video&limit=200"
    }

    /// Each placed image or video with the URL to draw it: the image's, or
    /// the video's poster frame. Placements with nothing to draw yet (an
    /// asset still processing, or none linked) are left out.
    static func placedArtwork(in data: Data) throws -> [LiveArtworkImage] {
        let page: ScreenshotAPIDocument<AssetLibraryPlacementAttributes, AssetLibraryFileAttributes>
        do {
            page = try JSONDecoder().decode(ScreenshotAPIDocument<AssetLibraryPlacementAttributes, AssetLibraryFileAttributes>.self, from: data)
        } catch {
            throw AppStoreConnectError.unexpectedPayload
        }
        let assets = Dictionary((page.included ?? []).map { (AssetKey(type: $0.type, id: $0.id), $0) }, uniquingKeysWith: { first, _ in first })
        return page.data.compactMap { placement -> LiveArtworkImage? in
            guard let type = placement.attributes?.placementType, StoreArtworkPlace(placementType: type) != nil,
                  let linked = shownAsset(of: placement), let image = assets[linked]?.attributes?.image,
                  let template = image.templateUrl else { return nil }
            let size = image.width.flatMap { width in image.height.map { PixelSize(width: width, height: $0) } }
            return LiveArtworkImage(
                placementID: placement.id, placementType: type, placementGroup: placement.attributes?.placementGroup,
                templateURL: template, pixelSize: size
            )
        }
    }

    /// An included resource's identity: an image and a video may share an ID.
    private struct AssetKey: Hashable {
        var type: String
        var id: String
    }

    /// The image the placement shows, else its video.
    private static func shownAsset(of placement: ScreenshotAPIResource<AssetLibraryPlacementAttributes>) -> AssetKey? {
        for media in [AssetLibraryMedia.image, .video] {
            if let linked = placement.related(media.relationship).first { return AssetKey(type: linked.type, id: linked.id) }
        }
        return nil
    }
}
