//
//  ReviewRiskScreenshotReader.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// Reads a live screenshot off the main actor: its text with Vision, in
/// the screenshot's language and English (`ArtworkTextReader`), and how
/// much of it is one flat area (`CaptureBlankness`).
enum ReviewRiskScreenshotReader {
    /// Nil when Vision can't read it.
    @concurrent
    static func reading(of image: CGImage, language: String) async -> ReviewRiskScreenshotReading? {
        guard let read = await ArtworkTextReader.read(image, language: language) else { return nil }
        let height = Double(max(1, image.height))
        let lines = read.compactMap { line -> ReviewRiskScreenshotLine? in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ReviewRiskScreenshotLine(text: text, top: (Double(line.frame.minY) / height * 1000).rounded() / 1000)
        }
        let blank = CaptureBlankness.largestBlankShare(of: image).map { ($0 * 100).rounded() / 100 }
        return ReviewRiskScreenshotReading(lines: lines, blankShare: blank)
    }
}
