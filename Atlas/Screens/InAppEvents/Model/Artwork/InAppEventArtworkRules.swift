//
//  InAppEventArtworkRules.swift
//  Atlas
//

import Foundation

/// Apple's rules for an In-App Event's card and details page media, as
/// "In-App Event media and audio specifications" (App Store Connect Help)
/// and the In-App Events guidelines state them, checked 2026-11-17:
///
/// - Card: 16:9, 1920 × 1080 up to 3840 × 2160. Details page: 9:16,
///   1080 × 1920 up to 2160 × 3840. Images and videos alike.
/// - Images .jpg, .jpeg or .png; videos .mov, .m4v or .mp4, 30 or 60 fps.
/// - 500 MB at most.
/// - Audio may be left out; when there is some it's stereo, 44.1 or
///   48 kHz, AAC (the details page also takes PCM).
/// - Videos play on repeat, so a seamless loop.
///
/// Apple states no codec, length, color space or transparency rule for
/// event media, so those are warnings here, never refusals.
enum InAppEventArtworkRules {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]
    static let videoExtensions: Set<String> = ["mov", "m4v", "mp4"]
    /// 500 MB, counted in the smaller (decimal) unit to be safe.
    static let maximumFileSize = 500_000_000
    static let frameRates: [Double] = [30, 60]
    static let audioSampleRates: [Double] = [44100, 48000]
    /// The codecs Apple's App Preview specifications name (H.264 and
    /// ProRes 422 HQ), and HEVC; anything else gets a warning.
    static let knownVideoCodecs: Set<String> = ["avc1", "hvc1", "hev1", "apch", "apcn"]

    static func minimumSize(for kind: InAppEventMedia.Kind) -> PixelSize {
        switch kind {
        case .card: PixelSize(width: 1920, height: 1080)
        case .details: PixelSize(width: 1080, height: 1920)
        }
    }

    static func maximumSize(for kind: InAppEventMedia.Kind) -> PixelSize {
        switch kind {
        case .card: PixelSize(width: 3840, height: 2160)
        case .details: PixelSize(width: 2160, height: 3840)
        }
    }

    /// The canvas `render_event_artwork` draws a page on.
    static func artworkKind(for kind: InAppEventMedia.Kind) -> AutopilotArtworkKind {
        switch kind {
        case .card: .eventCard
        case .details: .eventDetails
        }
    }

    /// Exactly 16:9 (or 9:16), give or take a pixel of rounding.
    static func hasRatio(_ size: PixelSize, of kind: InAppEventMedia.Kind) -> Bool {
        let ratio = maximumSize(for: kind)
        return abs(size.width * ratio.height - size.height * ratio.width) <= max(ratio.width, ratio.height)
    }

    /// `seconds` as Apple's poster frame time code, HH:MM:SS:FF, at
    /// `frameRate` frames a second.
    static func timeCode(seconds: Double, frameRate: Double) -> String {
        let rate = max(1, Int(frameRate.rounded()))
        let frames = Int((max(0, seconds) * Double(rate)).rounded(.down))
        let whole = frames / rate
        return String(format: "%02d:%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60, frames % rate)
    }

    static func fits(_ size: PixelSize, _ kind: InAppEventMedia.Kind) -> Bool {
        let low = minimumSize(for: kind)
        let high = maximumSize(for: kind)
        return size.width >= low.width && size.height >= low.height && size.width <= high.width && size.height <= high.height
            && hasRatio(size, of: kind)
    }
}
