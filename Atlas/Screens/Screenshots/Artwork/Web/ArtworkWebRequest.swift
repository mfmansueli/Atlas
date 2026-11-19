//
//  ArtworkWebRequest.swift
//  Atlas
//

import Foundation

/// One HTML page to render in one language: the HTML, the canvas
/// it's for, and what Atlas fills in.
struct ArtworkWebRequest: Sendable {
    var html: String
    var kind: AutopilotArtworkKind
    /// The App Store locale, e.g. "de-DE": the page's `lang`.
    var locale: String
    var isRightToLeft: Bool
    /// The placement's own text in this language (`data-al="headline"`).
    var headline: String
    var appName: String
    /// Each slot's picked capture (0-based slot, `data-slot` is 1-based),
    /// encoded as PNG.
    var captures: [Int: Data] = [:]
    var icon: Data?
    /// Where in the loop, in seconds: 0 is the poster.
    var time: Double = 0
    /// How wide the image comes back, in pixels; nil is the canvas's width.
    var pixelWidth: Int?
    /// The share of the canvas's pixels the page is drawn at: 0.5 lays it
    /// out at the canvas's size and draws it at half, for a loop or frames
    /// smaller than the canvas. Moving event art at 3840 × 2160 ended
    /// WebKit's page process again and again (Alba, 2026-11-18); drawn at
    /// the video's 1920 × 1080 it has a quarter of the pixels.
    var drawingScale: Double = 1
    /// The run's primary language: a page's phrases are written in it.
    /// Nil takes every phrase as written for this language.
    var primaryLocale: String?
    /// The page's phrases (`data-al="text"`) in this language, by their
    /// words in the primary language (`ArtworkTextBook.phraseTexts`).
    var phrases: [String: String] = [:]

    var pixelSize: PixelSize { kind.pixelSize }

    /// `pixelWidth`, at most the canvas's width.
    var outputWidth: Int { min(pixelWidth ?? pixelSize.width, pixelSize.width) }

    /// The width the page is drawn at: the canvas's at `drawingScale`.
    var drawnWidth: Int { Int((Double(pixelSize.width) * min(1, max(0.1, drawingScale))).rounded()) }

    var outputHeight: Int {
        Int((Double(pixelSize.height) * Double(outputWidth) / Double(pixelSize.width)).rounded())
    }
}
