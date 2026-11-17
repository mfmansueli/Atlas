//
//  AppEventMediaAttributes.swift
//  Atlas
//

import Foundation

/// An `appEventScreenshots` or `appEventVideoClips` resource: the image or
/// video of an event's card or details page.
struct AppEventMediaAttributes: Decodable, Sendable {
    struct ImageAsset: Decodable, Sendable {
        /// Ends in `{w}x{h}bb.{f}`.
        var templateUrl: String?
        var width: Int?
        var height: Int?

        /// The image no wider than `width` points, as a JPEG.
        func url(width target: Int) -> URL? {
            guard let templateUrl, let width, let height, width > 0 else { return nil }
            let scaled = max(1, height * target / width)
            return URL(string: templateUrl
                .replacingOccurrences(of: "{w}", with: String(target))
                .replacingOccurrences(of: "{h}", with: String(scaled))
                .replacingOccurrences(of: "{f}", with: "jpg"))
        }
    }

    /// A video clip's poster frame (`previewImage` is deprecated).
    struct PreviewFrameImage: Decodable, Sendable {
        var image: ImageAsset?
    }

    /// `EVENT_CARD` or `EVENT_DETAILS_PAGE`.
    var appEventAssetType: String?
    /// A screenshot's image.
    var imageAsset: ImageAsset?
    /// A video clip's poster frame, since API 4.0.
    var previewFrameImage: PreviewFrameImage?
    /// A video clip's poster, before `previewFrameImage`.
    var previewImage: ImageAsset?

    /// The image to show: a screenshot's, or a clip's poster frame.
    var shownImage: ImageAsset? { imageAsset ?? previewFrameImage?.image ?? previewImage }
}
