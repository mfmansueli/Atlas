//
//  LiveAppPreviewSet.swift
//  Atlas
//

import Foundation

/// A locale's App Previews for one display type. The Sets matrix shows
/// them in their own column with a lock; the language page changes them by
/// hand (`AppPreviewHandChange`).
struct LiveAppPreviewSet: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var locale: String
    var displayType: ScreenshotDisplayType
    var previewCount: Int
    /// The first preview's poster-frame time code, e.g. "00:00:05:00".
    var posterFrameTimeCode: String?
    /// The length in seconds when known. App Store Connect doesn't report
    /// it, so live previews leave it nil.
    var durationSeconds: Int?
    /// Each App Preview in the set's order; nil in sets read before Atlas
    /// kept them.
    var previews: [LiveAppPreview]?

    /// "0:24", or nil when the length isn't known.
    var durationTitle: String? {
        durationSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
    }
}
