//
//  PageShotsImage.swift
//  Atlas
//

import Foundation

/// One screenshot Atlas laid out for the page: a language, a device and a
/// place in the set, as a full-size PNG in the run's folder, ready to
/// upload.
struct PageShotsImage: Codable, Hashable, Sendable, Identifiable {
    var locale: String
    var displayType: ScreenshotDisplayType
    /// 0-based.
    var position: Int
    var fileName: String
    var fileSize: Int
    /// MD5, as App Store Connect checks an upload.
    var checksum: String
    /// The caption fits the template's caption box on this device.
    var fits: Bool

    var id: String { Self.makeID(locale: locale, displayType: displayType, position: position) }

    static func makeID(locale: String, displayType: ScreenshotDisplayType, position: Int) -> String {
        "\(locale)|\(displayType.rawValue)|\(position)"
    }

    /// "en-US-APP_IPHONE_67-1-3f2a9c1b.png": the place, then the start of
    /// its checksum, so a set laid out again has new names.
    static func fileName(locale: String, displayType: ScreenshotDisplayType, position: Int, checksum: String) -> String {
        "\(locale)-\(displayType.rawValue)-\(position + 1)-\(checksum.prefix(8)).png"
    }
}
