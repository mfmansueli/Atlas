//
//  ReviewRiskScreenshotFacts.swift
//  Atlas
//

import Foundation

/// The text read in the version's live screenshots and how each one looks
/// (`ReviewRiskFactsLoader.screenshotFacts`): the primary language's sets
/// on every device and up to 4 other languages' iPhone sets, the first 10
/// of each, at most 60 in all.
struct ReviewRiskScreenshotFacts: Hashable, Sendable {
    /// Every screenshot picked, in set order; `wasRead` false when its
    /// image couldn't be downloaded or read.
    var screenshots: [ReviewRiskScreenshot]
    /// Screenshots in the sets that weren't picked (past the caps, or with
    /// no image yet).
    var unreadCount: Int

    init(screenshots: [ReviewRiskScreenshot] = [], unreadCount: Int = 0) {
        self.screenshots = screenshots
        self.unreadCount = unreadCount
    }
}
