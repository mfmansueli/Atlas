//
//  InAppEventArtworkLook.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What an event card or details page shows, for the warnings: the words
/// Vision reads in it, and how busy its lower part is, where Apple lays
/// the badge, the event's name and its description.
struct InAppEventArtworkLook: Hashable, Sendable {
    /// The text read in the image (a video's poster frame).
    var text: [String] = []
    /// The share of the lower part's neighboring pixels that differ
    /// sharply, 0–1: flat color is 0, fine detail and edges push it up.
    var lowerBusyness = 0.0

    /// Where the lower part starts, as a fraction of the height.
    static let lowerPart = 0.6
    /// Past this, the overlaid name is hard to read.
    static let busyLimit = 0.12
    /// A step between neighbors this large (in luminance, 0–1) counts.
    static let edgeStep = 0.1

    var isLowerPartBusy: Bool { lowerBusyness > Self.busyLimit }

    /// Reads `image`'s text in `language` and measures its lower part.
    static func read(_ image: CGImage, language: String) async -> InAppEventArtworkLook {
        let read = await ArtworkTextReader.read(image, language: language) ?? []
        let words = read.map(\.text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count > 1 }
        return InAppEventArtworkLook(text: words, lowerBusyness: busyness(of: image))
    }

    /// The lower part's busyness (`lowerBusyness`), read at most 480
    /// pixels wide.
    static func busyness(of image: CGImage) -> Double {
        guard let pixels = ArtworkPixels(image) else { return 0 }
        let top = Int(Double(pixels.height) * lowerPart)
        var steps = 0
        var pairs = 0
        for y in top..<max(top, pixels.height - 1) {
            for x in 0..<max(0, pixels.width - 1) {
                let here = ArtworkContrast.luminance(pixels.color(x: x, y: y))
                let right = ArtworkContrast.luminance(pixels.color(x: x + 1, y: y))
                let below = ArtworkContrast.luminance(pixels.color(x: x, y: y + 1))
                if abs(here - right) > edgeStep { steps += 1 }
                if abs(here - below) > edgeStep { steps += 1 }
                pairs += 2
            }
        }
        return pairs == 0 ? 0 : Double(steps) / Double(pairs)
    }
}
