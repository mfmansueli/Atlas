//
//  ReviewRiskScreenshotReading.swift
//  Atlas
//

import Foundation

/// What Vision read in one live screenshot, kept on disk by its checksum
/// (`ReviewRiskOCRCache`) so a refresh doesn't read the same image twice.
struct ReviewRiskScreenshotReading: Codable, Hashable, Sendable {
    var lines: [ReviewRiskScreenshotLine]
    /// `CaptureBlankness.largestBlankShare(of:)`; nil when the image was
    /// too small to judge.
    var blankShare: Double?

    init(lines: [ReviewRiskScreenshotLine] = [], blankShare: Double? = nil) {
        self.lines = lines
        self.blankShare = blankShare
    }

    var texts: [String] { lines.map(\.text) }
}
