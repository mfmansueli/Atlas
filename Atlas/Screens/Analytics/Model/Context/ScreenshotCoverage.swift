//
//  ScreenshotCoverage.swift
//  Atlas
//

import Foundation

/// Which languages have screenshots of their own on each device, read from
/// the version's live sets in App Store Connect. Break It Down says it under
/// a device ("iPad 13″ set in 4 of 12 languages; the rest show the iPhone
/// set"), and a territory's facts say whether its page shows its own
/// language's screenshots.
struct ScreenshotCoverage: Hashable, Sendable {
    /// Each device's languages with at least one screenshot.
    var localesByDevice: [ScreenshotDisplayType: Set<String>]
    /// How many languages the App Store page has.
    var pageLocaleCount: Int

    init(localesByDevice: [ScreenshotDisplayType: Set<String>], pageLocaleCount: Int) {
        self.localesByDevice = localesByDevice
        self.pageLocaleCount = pageLocaleCount
    }

    init(live: LiveScreenshots, pageLocales: [StoreLocale]) {
        var byDevice: [ScreenshotDisplayType: Set<String>] = [:]
        for set in live.screenshotSets where !set.screenshots.isEmpty {
            byDevice[set.displayType, default: []].insert(set.locale)
        }
        self.init(localesByDevice: byDevice, pageLocaleCount: pageLocales.count)
    }

    /// Every language with screenshots of its own, on any device.
    var locales: Set<String> {
        localesByDevice.values.reduce(into: Set<String>()) { $0.formUnion($1) }
    }

    /// The set Apple's reports mean by a device name ("iPhone", "iPad",
    /// "Desktop", "Apple Watch"…); nil for one Atlas has no set for.
    static func displayType(forReportDevice device: String) -> ScreenshotDisplayType? {
        let name = device.lowercased()
        if name.contains("iphone") || name.contains("ipod") { return .iPhone }
        if name.contains("ipad") { return .iPad }
        if name.contains("desktop") || name.contains("mac") { return .mac }
        if name.contains("watch") { return .watch }
        if name.contains("vision") { return .visionPro }
        if name.contains("tv") { return .appleTV }
        return nil
    }

    /// What a device's people see, in one line, and whether it's worth
    /// fixing; nil for a device Atlas can't name a set for.
    func summary(forReportDevice device: String) -> (text: String, isWarning: Bool)? {
        guard let type = Self.displayType(forReportDevice: device) else { return nil }
        let locales = localesByDevice[type] ?? []
        let fallsBackToIPhone = type == .iPad || type == .iPhoneDuo
        if locales.isEmpty {
            let text = fallsBackToIPhone
                ? String(localized: "No \(type.title) set: the App Store shows the iPhone set", comment: "kind:label")
                : String(localized: "No \(type.title) set yet", comment: "kind:label")
            return (text, true)
        }
        if locales.count == 1, pageLocaleCount > 1, let only = locales.first {
            let name = StoreLocaleCatalog.locale(code: only)?.name ?? only
            return (String(localized: "\(type.title) set in \(name) only", comment: "kind:label"), true)
        }
        guard pageLocaleCount > locales.count else {
            return (String(localized: "\(type.title) set in \(locales.count) languages", comment: "kind:label"), false)
        }
        let partial = String(localized: "\(type.title) set in \(locales.count) of \(pageLocaleCount) languages", comment: "kind:label")
        guard fallsBackToIPhone else { return (partial, true) }
        return (partial + String(localized: "; the rest show the iPhone set", comment: "kind:label"), true)
    }
}
