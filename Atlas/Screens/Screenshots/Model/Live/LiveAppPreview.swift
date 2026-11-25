//
//  LiveAppPreview.swift
//  Atlas
//

import Foundation

/// One App Preview live in a set, as App Store Connect lists it: what the
/// Screenshots page names when it's replaced, moved or deleted by hand, and
/// what the App Store preview draws first (its poster frame and length).
struct LiveAppPreview: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// "Lumen-de.mov"; empty when App Store Connect doesn't say.
    var fileName: String
    /// "00:00:05:00".
    var posterFrameTimeCode: String?
    /// `previewImage`: the poster frame's URL with `{w}`, `{h}` and `{f}`
    /// placeholders; nil until Apple has processed the movie, and in
    /// previews read before Atlas asked for it.
    var posterURLTemplate: String?
    var posterPixelSize: PixelSize?
    /// `videoUrl`: where the processed movie streams from.
    var videoURL: URL?

    /// The poster frame at `width` pixels wide as PNG, when App Store
    /// Connect gave its template.
    func posterURL(width: Int) -> URL? {
        guard let posterURLTemplate, let posterPixelSize, posterPixelSize.width > 0 else { return nil }
        let height = Int((Double(width) * Double(posterPixelSize.height) / Double(posterPixelSize.width)).rounded())
        let text = posterURLTemplate
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{h}", with: "\(height)")
            .replacingOccurrences(of: "{f}", with: "png")
        return URL(string: text)
    }
}
