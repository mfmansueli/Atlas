//
//  ReviewRiskScreenshotLine.swift
//  Atlas
//

import Foundation

/// A line Vision read in a screenshot, and where it starts, from 0 at the
/// image's top to 1 at its bottom.
struct ReviewRiskScreenshotLine: Codable, Hashable, Sendable {
    var text: String
    var top: Double
}
