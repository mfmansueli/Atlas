//
//  ReviewViewerFile.swift
//  Atlas
//

import Foundation

/// A file the push progress opens large: an image read from it, a motion
/// loop or an event video that plays muted on repeat, or an App Preview
/// that plays with its sound and controls (`hasSound`). `pixelSize` sets
/// its proportions before it's read.
struct ReviewViewerFile: Hashable, Sendable {
    var url: URL
    var isVideo: Bool
    var pixelSize: PixelSize
    /// An App Preview: it plays with its sound, as the App Store plays it
    /// once tapped, and Sound Off mutes it.
    var hasSound = false

    /// The App Preview as the player takes it: its length is read from the
    /// movie, its device from its size.
    var previewFile: ExtrasPreviewFile {
        let display = ScreenshotDisplayType.allCases.first { display in
            guard let spec = AppPreviewSpec.spec(for: display, landscape: false) else { return false }
            return spec.pixelSize == pixelSize || spec.pixelSize.rotated == pixelSize
        } ?? .iPhone
        return ExtrasPreviewFile(
            displayType: display, locale: "", recordedLocale: "", fileID: url.lastPathComponent, seconds: 0, pixelSize: pixelSize,
            byteCount: 0, posterSeconds: 0, problems: []
        )
    }
}
