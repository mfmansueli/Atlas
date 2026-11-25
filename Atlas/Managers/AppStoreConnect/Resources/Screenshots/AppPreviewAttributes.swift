//
//  AppPreviewAttributes.swift
//  Atlas
//

import Foundation

/// An `appPreviews` resource's attributes. App Store Connect doesn't say
/// how long a preview is: the length is read from `videoUrl`'s movie.
struct AppPreviewAttributes: Decodable, Sendable {
    var fileName: String?
    /// The poster frame, e.g. "00:00:05:00".
    var previewFrameTimeCode: String?
    var mimeType: String?
    /// Where the processed movie streams from, once Apple has made it.
    var videoUrl: String?
    /// The poster frame as an image, once Apple has made it.
    var previewImage: AppScreenshotAttributes.ImageAsset?
}
