//
//  ReviewShotsCapture.swift
//  Atlas
//

import Foundation

/// A capture Screenshots already has of the paywall (README — Pricing:
/// review screenshots): a product missing its App Review screenshot can use
/// it with Use This Capture, no assistant needed.
struct ReviewShotsCapture: Hashable, Sendable {
    /// The PNG's checksum, its name in the app's `Captures` folder.
    var captureID: String
    /// Its screen's place in the plan, 1 for the first: “Capture 14”.
    var number: Int
    /// “Paywall”.
    var screenName: String
    var takenAt: Date
    var displayType: ScreenshotDisplayType
    /// “en-US”.
    var locale: String
    var pixelSize: PixelSize

    /// “Capture 14 · Paywall”.
    var title: String {
        String(localized: "Capture \(number) · \(screenName)")
    }

    /// “From the Screenshots run on Nov 20 · iPhone 17 Pro · English (U.S.)”.
    var origin: String {
        let day = takenAt.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "From the Screenshots run on \(day) · \(displayType.deviceName) · \(Self.languageName(locale))")
    }

    /// “English (United States)”, or the code when the system has no name.
    static func languageName(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    /// Where the PNG is, under the Screenshots documents' root.
    func url(appID: StoreApp.ID, root: URL) -> URL {
        root.appending(path: "\(appID)/Captures/\(captureID).png")
    }
}
