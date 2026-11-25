//
//  LanguagePageAppPreview.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// One App Preview at the start of the language page's row, as the App
/// Store plays it before the screenshots: a live one (its poster frame and
/// movie from App Store Connect), or a video waiting in Review & Push in
/// its place. Clicking it plays it.
struct LanguagePageAppPreview: Identifiable, Hashable {
    let id: String
    /// 0-based, among the set's App Previews.
    let position: Int
    let count: Int
    let locale: String
    let displayType: ScreenshotDisplayType
    /// "Lumen-de.mov"; empty when App Store Connect doesn't say.
    let fileName: String
    /// The live App Preview shown here; nil for a file not pushed yet, and
    /// in sets read before Atlas kept each preview.
    let live: LiveAppPreview?
    /// The video on this Mac that the push uploads here.
    let fileURL: URL?
    /// Height ÷ width, before the poster frame says.
    let aspect: CGFloat

    /// A video waiting in Review & Push, not on the App Store yet.
    var isPending: Bool { fileURL != nil }

    /// What plays: the file on this Mac, else the movie App Store Connect
    /// streams; nil until Apple has processed it.
    var movieURL: URL? { fileURL ?? live?.videoURL }

    /// "Live" or "Not pushed", under the tile like a screenshot's.
    var stateTitle: String {
        isPending ? String(localized: "Not pushed", comment: "kind:pill") : String(localized: "Live", comment: "kind:status")
    }

    /// The tile as the App Store preview's poster tile draws it.
    func slot(poster: ImageLoadPhase, seconds: Int?) -> PreviewAppPreviewSlot {
        PreviewAppPreviewSlot(
            id: id, preview: live, locale: locale, displayType: displayType, aspect: aspect, poster: poster, seconds: seconds
        )
    }

    /// Its size for the player: the poster frame's, else one at its shape.
    var pixelSize: PixelSize {
        if let size = live?.posterPixelSize, size.width > 0, size.height > 0 { return size }
        return PixelSize(width: 1000, height: Int((1000 * aspect).rounded()))
    }

    /// The App Preview as the player takes it: its length is read from the
    /// movie.
    var playerFile: ExtrasPreviewFile {
        ExtrasPreviewFile(
            displayType: displayType, locale: locale, recordedLocale: locale, fileID: id, seconds: 0, pixelSize: pixelSize,
            byteCount: 0, posterSeconds: 0, problems: []
        )
    }
}
