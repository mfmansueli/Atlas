//
//  AppEventMediaAttributes.swift
//  Atlas
//

import Foundation

/// An `appEventScreenshots` or `appEventVideoClips` resource: the image or
/// video of an event's card or details page, with the file's name and size
/// as it was uploaded and how Apple's processing went.
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

    /// Where Apple's processing is: `AWAITING_UPLOAD`, `UPLOAD_COMPLETE`,
    /// `PROCESSING` (a video), `COMPLETE` or `FAILED`, with its errors.
    struct DeliveryState: Decodable, Sendable {
        var state: String?
        var errors: [ScreenshotDeliveryMessage]?
    }

    /// A video clip's poster frame (`previewImage` is deprecated).
    struct PreviewFrameImage: Decodable, Sendable {
        var image: ImageAsset?
        var state: DeliveryState?
    }

    /// `EVENT_CARD` or `EVENT_DETAILS_PAGE`.
    var appEventAssetType: String?
    /// A screenshot's image.
    var imageAsset: ImageAsset?
    /// A video clip's poster frame, since API 4.0.
    var previewFrameImage: PreviewFrameImage?
    /// A video clip's poster, before `previewFrameImage`.
    var previewImage: ImageAsset?
    /// The name and size of the file as it was uploaded.
    var fileName: String?
    var fileSize: Int?
    /// A video clip's poster frame, "00:00:02:00".
    var previewFrameTimeCode: String?
    /// A screenshot's processing.
    var assetDeliveryState: DeliveryState?
    /// A video clip's processing.
    var videoDeliveryState: DeliveryState?

    /// The image to show: a screenshot's, or a clip's poster frame.
    var shownImage: ImageAsset? { imageAsset ?? previewFrameImage?.image ?? previewImage }

    /// The processing that counts for this kind of resource.
    func deliveryState(isVideo: Bool) -> DeliveryState? {
        isVideo ? videoDeliveryState ?? assetDeliveryState : assetDeliveryState
    }
}
