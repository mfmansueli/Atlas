//
//  SupportedDevice.swift
//  Atlas
//

import Foundation

/// A device the app runs on, with why Atlas thinks so: "Lumen runs
/// on iPad", "Lumen has a watch app, LumenWatch", "1.4 adds visionOS".
struct SupportedDevice: Codable, Hashable, Sendable {
    var displayType: ScreenshotDisplayType
    var reason: String
}
