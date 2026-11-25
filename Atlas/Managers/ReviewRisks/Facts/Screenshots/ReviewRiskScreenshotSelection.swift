//
//  ReviewRiskScreenshotSelection.swift
//  Atlas
//

import Foundation

/// Which live screenshots the App Review check reads: the primary
/// language's sets on every device, then up to 4 other languages' iPhone
/// sets (in the store page's order), the first 10 of each, at most 60 in
/// all. Screenshots without an image yet (still processing) are skipped.
struct ReviewRiskScreenshotSelection: Hashable, Sendable {
    static let perSet = 10
    static let otherLanguages = 4
    static let maximum = 60

    var picks: [ReviewRiskScreenshotPick]
    /// Screenshots in the sets that aren't read.
    var unreadCount: Int

    init(live: LiveScreenshots, primary: String, locales: [String]) {
        let nonEmpty = live.screenshotSets.filter { !$0.screenshots.isEmpty }
        let order = ScreenshotDisplayType.allCases
        let primarySets = nonEmpty
            .filter { $0.locale == primary }
            .sorted { (order.firstIndex(of: $0.displayType) ?? 0) < (order.firstIndex(of: $1.displayType) ?? 0) }
        var others: [LiveScreenshotSet] = []
        var otherLocales = locales.filter { $0 != primary }
        // Languages the store page doesn't list still count, after it.
        for set in nonEmpty where set.locale != primary && !otherLocales.contains(set.locale) {
            otherLocales.append(set.locale)
        }
        for locale in otherLocales where others.count < Self.otherLanguages {
            if let set = nonEmpty.first(where: { $0.locale == locale && $0.displayType == .iPhone }) { others.append(set) }
        }
        var picks: [ReviewRiskScreenshotPick] = []
        for set in primarySets + others {
            for (index, screenshot) in set.screenshots.prefix(Self.perSet).enumerated() where picks.count < Self.maximum {
                guard screenshot.missingImage == nil else { continue }
                picks.append(ReviewRiskScreenshotPick(locale: set.locale, displayType: set.displayType, slot: index + 1, screenshot: screenshot))
            }
        }
        self.picks = picks
        unreadCount = max(0, nonEmpty.reduce(0) { $0 + $1.screenshots.count } - picks.count)
    }
}
