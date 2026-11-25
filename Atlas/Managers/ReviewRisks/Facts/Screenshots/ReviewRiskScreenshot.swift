//
//  ReviewRiskScreenshot.swift
//  Atlas
//

import Foundation

/// One live screenshot as the checks read it: where it is, the text Vision
/// read in it, and whether it looks like something other than the app in
/// use (mostly blank, a system alert, a sign-in screen).
struct ReviewRiskScreenshot: Hashable, Sendable {
    /// The store locale code, e.g. "de-DE".
    var locale: String
    var displayType: ScreenshotDisplayType
    /// Its place in the set, from 1.
    var slot: Int
    /// The MD5 App Store Connect reports; the same image in two languages
    /// has the same one.
    var checksum: String?
    /// The lines Vision read, top to bottom.
    var lines: [String]
    /// False when its image couldn't be downloaded or read.
    var wasRead: Bool
    /// One flat area covers most of the screen.
    var isMostlyBlank: Bool
    /// The line of an iOS permission alert: "“Lumen” Would Like to Send You
    /// Notifications".
    var systemAlertLine: String?
    /// The lines that make it look like a sign-in screen ("Sign In",
    /// "Password"); empty when it doesn't.
    var signInLines: [String]

    init(
        locale: String,
        displayType: ScreenshotDisplayType,
        slot: Int,
        checksum: String? = nil,
        lines: [String] = [],
        wasRead: Bool = true,
        isMostlyBlank: Bool = false,
        systemAlertLine: String? = nil,
        signInLines: [String] = []
    ) {
        self.locale = locale
        self.displayType = displayType
        self.slot = slot
        self.checksum = checksum
        self.lines = lines
        self.wasRead = wasRead
        self.isMostlyBlank = isMostlyBlank
        self.systemAlertLine = systemAlertLine
        self.signInLines = signInLines
    }

    /// "APP_IPHONE_67.en-US": the set it's in.
    var setKey: String { "\(displayType.rawValue).\(locale)" }

    /// It doesn't show the app in use (2.3.3).
    var looksOutOfUse: Bool { isMostlyBlank || systemAlertLine != nil || !signInLines.isEmpty }

    /// "iPhone 6.9″ · English (U.S.) · screenshot 3", in evidence.
    var place: String {
        let language = StoreLocaleCatalog.locale(code: locale)?.name ?? locale
        return String(
            localized: "\(displayType.title) · \(language) · screenshot \(slot)",
            comment: "kind:label · where a live screenshot is: device, language, position"
        )
    }
}
