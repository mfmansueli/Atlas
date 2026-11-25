//
//  PreviewAppPreviewSlot.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// The App Preview the App Store preview's row starts with, as the App
/// Store plays it before the screenshots: its poster frame on its way or
/// shown, and its length once known.
struct PreviewAppPreviewSlot: Identifiable {
    let id: String
    /// Nil in a set read before Atlas kept each preview: there's no poster
    /// frame to load.
    var preview: LiveAppPreview?
    /// The set's language and device, which Screenshots opens on.
    var locale: String
    var displayType: ScreenshotDisplayType
    /// Height ÷ width, like a screenshot tile's.
    var aspect: CGFloat
    var poster: ImageLoadPhase
    /// Whole seconds; nil until it's known.
    var seconds: Int?

    /// "0:28", or nil while the length isn't known.
    var lengthTitle: String? {
        seconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
    }

    /// What VoiceOver says for the tile: name and length.
    var accessibilityLabel: String {
        guard let lengthTitle else { return String(localized: "App Preview", comment: "kind:label") }
        return String(localized: "App Preview, \(lengthTitle)", comment: "kind:label")
    }
}
