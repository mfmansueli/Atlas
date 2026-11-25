//
//  ReviewRiskFactsLoader+Screenshots.swift
//  Atlas
//

import CoreGraphics
import Foundation

extension ReviewRiskFactsLoader {
    /// How wide the screenshots are downloaded to be read: enough for
    /// Vision to read a caption and the app's own text.
    static let screenshotReadingWidth = 1200
    /// Screenshots downloaded and read at once.
    static let screenshotReadingBatch = 4

    /// The live screenshots of the version the store page shows
    /// (`ReviewRiskScreenshotSelection` picks which), each read with
    /// Vision off the main actor, or taken from `ReviewRiskOCRCache` by its
    /// checksum. Nil when the store page or the screenshot sets couldn't be
    /// read.
    func screenshotFacts(for app: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskScreenshotFacts? {
        guard let storePage = shared.storePage else { return nil }
        let localizations = storePage.ids.versionLocalizations
        guard !localizations.isEmpty else { return ReviewRiskScreenshotFacts() }
        let live: LiveScreenshots
        do {
            live = try await services.screenshots.liveScreenshots(for: app, localizations: localizations)
        } catch {
            return nil
        }
        let selection = ReviewRiskScreenshotSelection(live: live, primary: storePage.primaryLocale.code, locales: storePage.locales.map(\.code))
        let cache = ReviewRiskOCRCache.shared
        var screenshots: [ReviewRiskScreenshot] = []
        for start in stride(from: 0, to: selection.picks.count, by: Self.screenshotReadingBatch) {
            let batch = Array(selection.picks[start..<min(start + Self.screenshotReadingBatch, selection.picks.count)])
            let tasks = batch.map { pick in Task { await reading(of: pick, cache: cache) } }
            for (pick, task) in zip(batch, tasks) {
                let reading = await task.value
                screenshots.append(Self.screenshot(pick, reading: reading, appName: app.name))
            }
        }
        return ReviewRiskScreenshotFacts(screenshots: screenshots, unreadCount: selection.unreadCount)
    }

    /// The kept reading, else the image downloaded and read (and kept).
    private func reading(of pick: ReviewRiskScreenshotPick, cache: ReviewRiskOCRCache) async -> ReviewRiskScreenshotReading? {
        let key = ReviewRiskOCRCache.key(checksum: pick.screenshot.checksum, screenshotID: pick.screenshot.id, locale: pick.locale)
        if let key, let kept = cache.reading(for: key) { return kept }
        let width = min(Self.screenshotReadingWidth, pick.screenshot.pixelSize?.width ?? Self.screenshotReadingWidth)
        guard let image = await services.screenshots.liveImage(pick.screenshot, pixelWidth: width) else { return nil }
        let read = await ReviewRiskScreenshotReader.reading(of: image, language: pick.locale)
        guard let reading = read else { return nil }
        if let key { cache.keep(reading, for: key) }
        return reading
    }

    /// The facts of one screenshot from what was read in it.
    static func screenshot(_ pick: ReviewRiskScreenshotPick, reading: ReviewRiskScreenshotReading?, appName: String) -> ReviewRiskScreenshot {
        guard let reading else {
            return ReviewRiskScreenshot(
                locale: pick.locale, displayType: pick.displayType, slot: pick.slot, checksum: pick.screenshot.checksum, wasRead: false
            )
        }
        let lines = reading.texts
        return ReviewRiskScreenshot(
            locale: pick.locale,
            displayType: pick.displayType,
            slot: pick.slot,
            checksum: pick.screenshot.checksum,
            lines: lines,
            isMostlyBlank: ReviewRiskScreenshotLooks.isMostlyBlank(reading, on: pick.displayType),
            systemAlertLine: ReviewRiskScreenshotLooks.systemAlertLine(in: lines, appName: appName),
            signInLines: ReviewRiskScreenshotLooks.signInLines(in: lines)
        )
    }
}
