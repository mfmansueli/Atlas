//
//  PageShotsNewCapture.swift
//  Atlas
//

import Foundation

/// A screen of the default set captured again for a page (board 52: “2
/// are captured again so the lock shows”): the assistant ran the app in the
/// Simulator and sent the PNG. It's kept in the app's Captures folder, and
/// the default page's capture doesn't change.
struct PageShotsNewCapture: Codable, Hashable, Sendable {
    /// The default set's slot (0-based) it stands in for.
    var slot: Int
    var locale: String
    var displayType: ScreenshotDisplayType
    /// The PNG's checksum: its name in the Captures folder.
    var captureID: String
    var pixelSize: PixelSize
    /// What it shows now, in the assistant's words.
    var notes: String
    var receivedAt: Date

    /// As a capture the layout engine reads.
    var capture: ScreenshotCapture {
        ScreenshotCapture(
            id: captureID, locale: locale, displayType: displayType, slot: slot, source: .autopilot, fileName: "\(captureID).png",
            pixelSize: pixelSize, importedAt: receivedAt
        )
    }
}
