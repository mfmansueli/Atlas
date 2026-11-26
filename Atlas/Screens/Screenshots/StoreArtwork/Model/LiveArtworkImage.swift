//
//  LiveArtworkImage.swift
//  Atlas
//

import Foundation

/// One header or search image App Store Connect shows on a version
/// localization's page: the placement it's in and Apple's image URL.
struct LiveArtworkImage: Codable, Hashable, Sendable {
    var placementID: String
    var placementType: String
    var placementGroup: String?
    /// Apple's image URL with `{w}`, `{h}` and `{f}` to fill in: the
    /// image's, or a moving one's poster frame.
    var templateURL: String
    var pixelSize: PixelSize?

    var place: StoreArtworkPlace? { StoreArtworkPlace(placementType: placementType) }

    /// The image at about `width` pixels wide, keeping its shape (the
    /// place's when the size isn't known).
    func url(width: Int) -> URL? {
        let shape = pixelSize ?? place?.kind.pixelSize ?? PixelSize(width: 21, height: 9)
        let height = Int((Double(width) * Double(shape.height) / Double(max(1, shape.width))).rounded())
        let filled = templateURL
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{h}", with: "\(height)")
            .replacingOccurrences(of: "{f}", with: "png")
        return URL(string: filled)
    }
}
