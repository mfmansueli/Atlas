//
//  ReviewRiskScreenshotPick.swift
//  Atlas
//

import Foundation

/// A live screenshot chosen to be read, and where it is.
struct ReviewRiskScreenshotPick: Hashable, Sendable {
    var locale: String
    var displayType: ScreenshotDisplayType
    /// Its place in the set, from 1.
    var slot: Int
    var screenshot: LiveScreenshot
}
