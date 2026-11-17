//
//  InAppEventArtworkFile.swift
//  Atlas
//

import Foundation

/// What Atlas read from an event card or details page file, made
/// here or sent by an assistant: enough to hold it against Apple's rules.
struct InAppEventArtworkFile: Hashable, Sendable {
    /// The audio of a video, when it has any.
    struct Audio: Hashable, Sendable {
        /// "aac", "lpcm" or the format's four-character code.
        var format: String
        var channels: Int
        var sampleRate: Double
    }

    var fileName: String
    var fileSize: Int
    var isVideo: Bool
    /// Width and height as shown (a video's turned by its transform).
    var pixelSize: PixelSize
    var hasAlpha = false
    /// ImageIO's color model, e.g. "RGB", "CMYK" or "Gray"; nil for a
    /// video.
    var colorModel: String?
    var frameRate: Double?
    var seconds: Double?
    /// The video's four-character codec, e.g. "avc1".
    var codec: String?
    var audio: [Audio] = []

    var fileExtension: String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }

    /// "Image" or "Video (0:20)".
    var title: String {
        guard isVideo else { return String(localized: "Image") }
        guard let seconds else { return String(localized: "Video") }
        let whole = Int(seconds.rounded())
        return String(localized: "Video (\(whole / 60):\(String(format: "%02d", whole % 60)))")
    }
}
